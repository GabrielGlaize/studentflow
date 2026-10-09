using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using StudyFlow.Application.Notifications;
using StudyFlow.Application.Security;
using StudyFlow.Application.Time;
using StudyFlow.Domain.Exams;
using StudyFlow.Domain.Notifications;
using StudyFlow.Domain.School;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Infrastructure.Notifications;

public sealed class NotificationReminderPlanner(
    StudyFlowDbContext dbContext,
    ISensitiveDataProtector protector,
    ISchoolClock clock) : INotificationReminderPlanner
{
    private const string CourseDataPurpose = "course-data";
    private const string PersonalEventDataPurpose = "personal-event-data";

    /// <summary>Heure d'envoi de l'annonce d'ouverture de la fiche de révision des partiels.</summary>
    private static readonly TimeOnly ExamOpeningTime = new(8, 0);
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
        candidates.AddRange(await PlanExamOpeningsAsync(
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
        var firstDay = clock.ToSchoolDay(windowStart).AddDays(-1);
        var lastDay = clock.ToSchoolDay(windowEnd).AddDays(1);

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

                // Les horaires sont saisis en heure de l'établissement, quel que soit le fuseau du serveur.
                var courseStart = clock.ToSchoolTime(course.Day, data.StartsAt);
                // PostgreSQL (timestamptz via Npgsql) n'accepte que des instants en UTC.
                var scheduledAt = courseStart.AddMinutes(-preference.CourseReminderMinutes).ToUniversalTime();
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
        // Chaque élève choisit son délai (jusqu'à 30 jours avant) : on charge large puis on filtre.
        var deadlineStart = windowStart;
        var deadlineEnd = windowEnd.AddMinutes(ReminderDefaults.MaxMinutes);

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

                var minutesBefore = progress?.ReminderMinutesBefore ?? ReminderDefaults.HomeworkMinutes;
                var scheduledAt = homework.Deadline.AddMinutes(-minutesBefore).ToUniversalTime();
                if (!IsInsideWindow(scheduledAt, windowStart, windowEnd)) continue;

                candidates.Add(new NotificationReminderCandidate(
                    Type: "homework",
                    UserId: userId,
                    RelatedEntityId: homework.Id,
                    Title: $"Devoir à rendre {ReminderWording.Relative(minutesBefore)}",
                    Body: homework.Title,
                    ScheduledAt: scheduledAt,
                    DeviceCount: deviceCount));
            }
        }

        return candidates;
    }

    /// <summary>Le matin où la fiche de révision s'ouvre (deux semaines avant), toute la classe est prévenue.</summary>
    private async Task<IReadOnlyCollection<NotificationReminderCandidate>> PlanExamOpeningsAsync(
        Guid schoolClassId,
        IEnumerable<Guid> userIds,
        IReadOnlyDictionary<Guid, NotificationPreference> preferences,
        IReadOnlyDictionary<Guid, int> deviceCounts,
        DateTimeOffset windowStart,
        DateTimeOffset windowEnd,
        CancellationToken cancellationToken)
    {
        var firstOpening = clock.ToSchoolDay(windowStart).AddDays(ExamSession.OpensDaysBefore - 1);
        var lastOpening = clock.ToSchoolDay(windowEnd).AddDays(ExamSession.OpensDaysBefore + 1);
        var sessions = await dbContext.ExamSessions
            .AsNoTracking()
            .Where(x => x.SchoolClassId == schoolClassId && x.StartsOn >= firstOpening && x.StartsOn <= lastOpening)
            .ToListAsync(cancellationToken);

        var candidates = new List<NotificationReminderCandidate>();
        foreach (var session in sessions)
        {
            var scheduledAt = clock.ToSchoolTime(session.OpensOn, ExamOpeningTime).ToUniversalTime();
            if (!IsInsideWindow(scheduledAt, windowStart, windowEnd)) continue;

            foreach (var userId in userIds)
            {
                var deviceCount = deviceCounts.GetValueOrDefault(userId);
                if (!GetPreference(preferences, userId).HomeworkEnabled || deviceCount == 0) continue;

                candidates.Add(new NotificationReminderCandidate(
                    Type: "exams",
                    UserId: userId,
                    RelatedEntityId: session.Id,
                    Title: "Partiels dans 2 semaines",
                    Body: $"La fiche de révision « {session.Title} » est ouverte : ajoute ce qu'il faut réviser.",
                    ScheduledAt: scheduledAt,
                    DeviceCount: deviceCount));
            }
        }

        return candidates;
    }

    public async Task<IReadOnlyCollection<NotificationReminderCandidate>> PlanPersonalRemindersAsync(
        DateTimeOffset windowStart,
        DateTimeOffset windowEnd,
        CancellationToken cancellationToken)
    {
        var deviceCounts = await dbContext.NotificationDevices
            .AsNoTracking()
            .GroupBy(x => x.UserId)
            .Select(x => new { UserId = x.Key, Count = x.Count() })
            .ToDictionaryAsync(x => x.UserId, x => x.Count, cancellationToken);
        if (deviceCounts.Count == 0) return [];

        var userIds = deviceCounts.Keys.ToArray();
        var latest = windowEnd.AddMinutes(ReminderDefaults.MaxMinutes);
        var candidates = new List<NotificationReminderCandidate>();

        var tasks = await dbContext.PersonalTasks
            .AsNoTracking()
            .Where(x => userIds.Contains(x.UserId)
                && x.NotificationsEnabled
                && !x.IsDone
                && x.Deadline != null
                && x.Deadline >= windowStart
                && x.Deadline <= latest)
            .ToListAsync(cancellationToken);
        foreach (var task in tasks)
        {
            var scheduledAt = task.Deadline!.Value.AddMinutes(-task.ReminderMinutesBefore).ToUniversalTime();
            if (!IsInsideWindow(scheduledAt, windowStart, windowEnd)) continue;

            candidates.Add(new NotificationReminderCandidate(
                Type: "task",
                UserId: task.UserId,
                RelatedEntityId: task.Id,
                Title: $"Tâche à terminer {ReminderWording.Relative(task.ReminderMinutesBefore)}",
                Body: task.Title,
                ScheduledAt: scheduledAt,
                DeviceCount: deviceCounts[task.UserId]));
        }

        var firstDay = clock.ToSchoolDay(windowStart).AddDays(-1);
        var lastDay = clock.ToSchoolDay(latest).AddDays(1);
        var events = await dbContext.PersonalEvents
            .AsNoTracking()
            .Where(x => userIds.Contains(x.UserId)
                && x.NotificationsEnabled
                && x.Day >= firstDay
                && x.Day <= lastDay)
            .ToListAsync(cancellationToken);
        foreach (var personalEvent in events)
        {
            var data = JsonSerializer.Deserialize<PersonalEventProtectedData>(
                protector.Unprotect(personalEvent.EncryptedData, PersonalEventDataPurpose),
                JsonOptions)!;
            var startsAt = clock.ToSchoolTime(personalEvent.Day, data.StartsAt);
            var scheduledAt = startsAt.AddMinutes(-personalEvent.ReminderMinutesBefore).ToUniversalTime();
            if (!IsInsideWindow(scheduledAt, windowStart, windowEnd)) continue;

            var body = $"Commence {ReminderWording.Relative(personalEvent.ReminderMinutesBefore)} ({FrenchCalendar.Time(data.StartsAt)})";
            if (!string.IsNullOrWhiteSpace(data.Location)) body += $" · {data.Location}";

            candidates.Add(new NotificationReminderCandidate(
                Type: "event",
                UserId: personalEvent.UserId,
                RelatedEntityId: personalEvent.Id,
                Title: data.Title,
                Body: body,
                ScheduledAt: scheduledAt,
                DeviceCount: deviceCounts[personalEvent.UserId]));
        }

        return candidates.OrderBy(x => x.ScheduledAt).ToArray();
    }

    private static NotificationPreference GetPreference(
        IReadOnlyDictionary<Guid, NotificationPreference> preferences,
        Guid userId)
    {
        return preferences.GetValueOrDefault(userId) ?? new NotificationPreference { UserId = userId };
    }

    private static bool IsInsideWindow(DateTimeOffset value, DateTimeOffset start, DateTimeOffset end) =>
        value >= start && value <= end;

    private sealed record CourseProtectedData(TimeOnly StartsAt, TimeOnly EndsAt, string Room);

    private sealed record PersonalEventProtectedData(
        string Title,
        TimeOnly StartsAt,
        TimeOnly EndsAt,
        string? Location,
        string? Notes);
}
