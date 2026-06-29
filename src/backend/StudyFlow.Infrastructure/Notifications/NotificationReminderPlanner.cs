using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using StudyFlow.Application.Notifications;
using StudyFlow.Application.Security;
using StudyFlow.Domain.Notifications;
using StudyFlow.Domain.School;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Infrastructure.Notifications;

public sealed class NotificationReminderPlanner(
    StudyFlowDbContext dbContext,
    ISensitiveDataProtector protector) : INotificationReminderPlanner
{
    private const string CourseDataPurpose = "course-data";
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public async Task<IReadOnlyCollection<NotificationReminderCandidate>> PlanClassRemindersAsync(
        Guid schoolClassId,
        DateTimeOffset windowStart,
        DateTimeOffset windowEnd,
        CancellationToken cancellationToken)
    {
        if (windowEnd < windowStart)
        {
            throw new ArgumentException("La fin de fenêtre doit être après le début.");
        }

        var users = await dbContext.Users
            .AsNoTracking()
            .Where(x => x.SchoolClassId == schoolClassId && x.IsActive)
            .Select(x => new { x.Id })
            .ToListAsync(cancellationToken);

        if (users.Count == 0) return [];

        var userIds = users.Select(x => x.Id).ToArray();
        var preferences = await dbContext.NotificationPreferences
            .AsNoTracking()
            .Where(x => userIds.Contains(x.UserId))
            .ToDictionaryAsync(x => x.UserId, cancellationToken);

        var deviceCounts = await dbContext.NotificationDevices
            .AsNoTracking()
            .Where(x => userIds.Contains(x.UserId))
            .GroupBy(x => x.UserId)
            .Select(x => new { UserId = x.Key, Count = x.Count() })
            .ToDictionaryAsync(x => x.UserId, x => x.Count, cancellationToken);

        var candidates = new List<NotificationReminderCandidate>();
        candidates.AddRange(await PlanCourseRemindersAsync(
            schoolClassId,
            users.Select(x => x.Id),
            preferences,
            deviceCounts,
            windowStart,
            windowEnd,
            cancellationToken));
        candidates.AddRange(await PlanHomeworkRemindersAsync(
            schoolClassId,
            users.Select(x => x.Id),
            preferences,
            deviceCounts,
            windowStart,
            windowEnd,
            cancellationToken));

        return candidates
            .OrderBy(x => x.ScheduledAt)
            .ThenBy(x => x.Type)
            .ToArray();
    }

    private async Task<IReadOnlyCollection<NotificationReminderCandidate>> PlanCourseRemindersAsync(
        Guid schoolClassId,
        IEnumerable<Guid> userIds,
        IReadOnlyDictionary<Guid, NotificationPreference> preferences,
        IReadOnlyDictionary<Guid, int> deviceCounts,
        DateTimeOffset windowStart,
        DateTimeOffset windowEnd,
        CancellationToken cancellationToken)
    {
        var firstDay = DateOnly.FromDateTime(windowStart.LocalDateTime).AddDays(-1);
        var lastDay = DateOnly.FromDateTime(windowEnd.LocalDateTime).AddDays(1);

        var courses = await dbContext.Courses
            .AsNoTracking()
            .Include(x => x.Subject)
            .Where(x => x.SchoolClassId == schoolClassId
                && x.DeletedAt == null
                && x.Day >= firstDay
                && x.Day <= lastDay
                && !x.IsCancelled)
            .ToListAsync(cancellationToken);

        var candidates = new List<NotificationReminderCandidate>();
        foreach (var userId in userIds)
        {
            var preference = GetPreference(preferences, userId);
            var deviceCount = deviceCounts.GetValueOrDefault(userId);
            if (!preference.CoursesEnabled || deviceCount == 0) continue;

            foreach (var course in courses)
            {
                var data = JsonSerializer.Deserialize<CourseProtectedData>(
                    protector.Unprotect(course.EncryptedData, CourseDataPurpose),
                    JsonOptions)!;

                var courseStart = ToDateTimeOffset(course.Day, data.StartsAt, windowStart.Offset);
                var scheduledAt = courseStart.AddMinutes(-preference.CourseReminderMinutes);
                if (!IsInsideWindow(scheduledAt, windowStart, windowEnd)) continue;

                var title = preference.CourseReminderMinutes == 0
                    ? "Cours maintenant"
                    : $"Cours dans {preference.CourseReminderMinutes} min";

                candidates.Add(new NotificationReminderCandidate(
                    Type: "course",
                    UserId: userId,
                    RelatedEntityId: course.Id,
                    Title: title,
                    Body: $"{course.Subject.Name} - salle {data.Room}",
                    ScheduledAt: scheduledAt,
                    DeviceCount: deviceCount));
            }
        }

        return candidates;
    }

    private async Task<IReadOnlyCollection<NotificationReminderCandidate>> PlanHomeworkRemindersAsync(
        Guid schoolClassId,
        IEnumerable<Guid> userIds,
        IReadOnlyDictionary<Guid, NotificationPreference> preferences,
        IReadOnlyDictionary<Guid, int> deviceCounts,
        DateTimeOffset windowStart,
        DateTimeOffset windowEnd,
        CancellationToken cancellationToken)
    {
        var deadlineStart = windowStart.AddDays(1);
        var deadlineEnd = windowEnd.AddDays(1);

        var homeworkItems = await dbContext.HomeworkItems
            .AsNoTracking()
            .Where(x => x.SchoolClassId == schoolClassId
                && x.DeletedAt == null
                && x.Deadline >= deadlineStart
                && x.Deadline <= deadlineEnd)
            .OrderBy(x => x.Deadline)
            .ToListAsync(cancellationToken);

        if (homeworkItems.Count == 0) return [];

        var homeworkIds = homeworkItems.Select(x => x.Id).ToArray();
        var userIdArray = userIds.ToArray();
        var progressItems = await dbContext.HomeworkProgressItems
            .AsNoTracking()
            .Where(x => homeworkIds.Contains(x.HomeworkId) && userIdArray.Contains(x.UserId))
            .ToListAsync(cancellationToken);

        var progressByUserAndHomework = progressItems.ToDictionary(x => (x.UserId, x.HomeworkId));
        var candidates = new List<NotificationReminderCandidate>();

        foreach (var userId in userIdArray)
        {
            var preference = GetPreference(preferences, userId);
            var deviceCount = deviceCounts.GetValueOrDefault(userId);
            if (!preference.HomeworkEnabled || deviceCount == 0) continue;

            foreach (var homework in homeworkItems)
            {
                var progress = progressByUserAndHomework.GetValueOrDefault((userId, homework.Id));
                if (progress?.IsDone == true || progress?.NotificationsEnabled == false) continue;

                var scheduledAt = homework.Deadline.AddDays(-1);
                if (!IsInsideWindow(scheduledAt, windowStart, windowEnd)) continue;

                candidates.Add(new NotificationReminderCandidate(
                    Type: "homework",
                    UserId: userId,
                    RelatedEntityId: homework.Id,
                    Title: "Devoir à rendre demain",
                    Body: homework.Title,
                    ScheduledAt: scheduledAt,
                    DeviceCount: deviceCount));
            }
        }

        return candidates;
    }

    private static NotificationPreference GetPreference(
        IReadOnlyDictionary<Guid, NotificationPreference> preferences,
        Guid userId)
    {
        return preferences.GetValueOrDefault(userId) ?? new NotificationPreference { UserId = userId };
    }

    private static DateTimeOffset ToDateTimeOffset(DateOnly day, TimeOnly time, TimeSpan offset)
    {
        var dateTime = day.ToDateTime(time);
        return new DateTimeOffset(dateTime, offset);
    }

    private static bool IsInsideWindow(DateTimeOffset value, DateTimeOffset start, DateTimeOffset end) =>
        value >= start && value <= end;

    private sealed record CourseProtectedData(TimeOnly StartsAt, TimeOnly EndsAt, string Room);
}
