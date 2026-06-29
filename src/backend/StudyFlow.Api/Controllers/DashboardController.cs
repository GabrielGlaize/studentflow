using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StudyFlow.Api.Contracts;
using StudyFlow.Application.Security;
using StudyFlow.Domain.School;
using StudyFlow.Infrastructure.Identity;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/dashboard")]
public sealed class DashboardController(
    UserManager<ApplicationUser> userManager,
    StudyFlowDbContext dbContext,
    ISensitiveDataProtector protector) : ControllerBase
{
    private const string CourseDataPurpose = "course-data";
    private const string PersonalEventDataPurpose = "personal-event-data";
    private const string TeacherDisplayPurpose = "teacher-display-name";

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    [HttpGet]
    public async Task<ActionResult<DashboardResponse>> Get(
        [FromQuery] int homeworkLimit = 5,
        [FromQuery] int taskLimit = 5,
        CancellationToken cancellationToken = default)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();

        var now = DateTimeOffset.UtcNow;
        var today = DateOnly.FromDateTime(DateTime.Today);
        var homework = user.SchoolClassId is null
            ? []
            : await GetUpcomingHomeworkAsync(user.SchoolClassId.Value, user.Id, homeworkLimit, now, cancellationToken);

        var response = new DashboardResponse(
            GeneratedAt: now,
            HasClass: user.SchoolClassId is not null,
            NextCourse: user.SchoolClassId is null
                ? null
                : await GetNextCourseAsync(user.SchoolClassId.Value, today, TimeOnly.FromDateTime(DateTime.Now), cancellationToken),
            PinnedAnnouncements: user.SchoolClassId is null
                ? []
                : await GetPinnedAnnouncementsAsync(user.SchoolClassId.Value, cancellationToken),
            UpcomingHomework: homework,
            PersonalTasks: await GetPersonalTasksAsync(user.Id, taskLimit, cancellationToken),
            TodayEvents: await GetTodayEventsAsync(user.Id, today, cancellationToken));

        return Ok(response);
    }

    private async Task<CourseResponse?> GetNextCourseAsync(
        Guid schoolClassId,
        DateOnly today,
        TimeOnly currentTime,
        CancellationToken cancellationToken)
    {
        // Les horaires sont chiffres en base, donc on charge une petite fenetre puis on trie apres dechiffrement.
        var courses = await dbContext.Courses
            .AsNoTracking()
            .Include(x => x.Subject)
            .Include(x => x.Teacher)
            .Where(x => x.SchoolClassId == schoolClassId
                && x.DeletedAt == null
                && x.Day >= today
                && x.Day <= today.AddDays(14)
                && !x.IsCancelled)
            .OrderBy(x => x.Day)
            .Take(80)
            .ToListAsync(cancellationToken);

        return courses
            .Select(ToCourseResponse)
            .Where(x => x.Day > today || x.StartsAt >= currentTime)
            .OrderBy(x => x.Day)
            .ThenBy(x => x.StartsAt)
            .FirstOrDefault();
    }

    private async Task<IReadOnlyCollection<HomeworkResponse>> GetUpcomingHomeworkAsync(
        Guid schoolClassId,
        Guid userId,
        int limit,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        var safeLimit = Math.Clamp(limit, 1, 20);

        var homework = await dbContext.HomeworkItems
            .AsNoTracking()
            .Include(x => x.ProgressItems.Where(progress => progress.UserId == userId))
            .Where(x => x.SchoolClassId == schoolClassId
                && x.DeletedAt == null
                && x.Deadline >= now)
            .OrderBy(x => x.Deadline)
            .Take(safeLimit * 3)
            .ToListAsync(cancellationToken);

        return homework
            .Where(x => x.ProgressItems.SingleOrDefault()?.IsDone != true)
            .Take(safeLimit)
            .Select(ToHomeworkResponse)
            .ToArray();
    }

    private async Task<IReadOnlyCollection<ClassAnnouncementResponse>> GetPinnedAnnouncementsAsync(
        Guid schoolClassId,
        CancellationToken cancellationToken)
    {
        var announcements = await dbContext.ClassAnnouncements
            .AsNoTracking()
            .Where(x => x.SchoolClassId == schoolClassId
                && x.DeletedAt == null
                && x.IsPinned)
            .OrderByDescending(x => x.CreatedAt)
            .Take(3)
            .ToListAsync(cancellationToken);

        var authorIds = announcements.Select(x => x.AuthorId).Distinct().ToArray();
        var authors = await dbContext.Users
            .AsNoTracking()
            .Where(x => authorIds.Contains(x.Id))
            .ToDictionaryAsync(x => x.Id, x => $"{x.FirstName} {x.LastName}".Trim(), cancellationToken);

        return announcements.Select(x => new ClassAnnouncementResponse(
            x.Id,
            x.Content,
            x.IsPinned,
            x.AuthorId,
            authors.GetValueOrDefault(x.AuthorId, "Utilisateur inconnu"),
            x.CreatedAt,
            x.UpdatedAt)).ToArray();
    }

    private async Task<IReadOnlyCollection<PersonalTaskResponse>> GetPersonalTasksAsync(
        Guid userId,
        int limit,
        CancellationToken cancellationToken)
    {
        var safeLimit = Math.Clamp(limit, 1, 20);

        var tasks = await dbContext.PersonalTasks
            .AsNoTracking()
            .Where(x => x.UserId == userId && !x.IsDone)
            .OrderBy(x => x.Deadline == null)
            .ThenBy(x => x.Deadline)
            .ThenBy(x => x.CreatedAt)
            .Take(safeLimit)
            .ToListAsync(cancellationToken);

        return tasks.Select(ToPersonalTaskResponse).ToArray();
    }

    private async Task<IReadOnlyCollection<PersonalEventResponse>> GetTodayEventsAsync(
        Guid userId,
        DateOnly today,
        CancellationToken cancellationToken)
    {
        var events = await dbContext.PersonalEvents
            .AsNoTracking()
            .Where(x => x.UserId == userId && x.Day == today)
            .OrderBy(x => x.CreatedAt)
            .ToListAsync(cancellationToken);

        return events.Select(ToPersonalEventResponse).OrderBy(x => x.StartsAt).ToArray();
    }

    private CourseResponse ToCourseResponse(Course course)
    {
        var data = JsonSerializer.Deserialize<CourseProtectedData>(
            protector.Unprotect(course.EncryptedData, CourseDataPurpose),
            JsonOptions)!;

        return new CourseResponse(
            course.Id,
            course.SubjectId,
            course.Subject.Name,
            course.TeacherId,
            course.Teacher is null ? null : protector.Unprotect(course.Teacher.EncryptedDisplayName, TeacherDisplayPurpose),
            course.Day,
            data.StartsAt,
            data.EndsAt,
            data.Room,
            course.IsCancelled,
            course.Version);
    }

    private static HomeworkResponse ToHomeworkResponse(Homework homework) => new(
        homework.Id,
        homework.Title,
        homework.Description,
        homework.Deadline,
        homework.CourseId,
        homework.ProgressItems.SingleOrDefault()?.IsDone ?? false,
        homework.ProgressItems.SingleOrDefault()?.NotificationsEnabled ?? true,
        homework.ProgressItems.SingleOrDefault()?.CompletedAt,
        homework.CreatedAt,
        homework.UpdatedAt);

    private static PersonalTaskResponse ToPersonalTaskResponse(PersonalTask task) => new(
        task.Id,
        task.Title,
        task.Description,
        task.Deadline,
        ToTaskCategoryName(task.Category),
        task.IsDone,
        task.NotificationsEnabled,
        task.CourseId,
        task.CreatedAt,
        task.UpdatedAt);

    private PersonalEventResponse ToPersonalEventResponse(PersonalEvent personalEvent)
    {
        var data = JsonSerializer.Deserialize<PersonalEventProtectedData>(
            protector.Unprotect(personalEvent.EncryptedData, PersonalEventDataPurpose),
            JsonOptions)!;

        return new PersonalEventResponse(
            personalEvent.Id,
            data.Title,
            personalEvent.Day,
            data.StartsAt,
            data.EndsAt,
            ToEventCategoryName(personalEvent.Category),
            data.Location,
            data.Notes,
            personalEvent.NotificationsEnabled,
            personalEvent.CreatedAt,
            personalEvent.UpdatedAt);
    }

    private static string ToTaskCategoryName(PersonalTaskCategory category) =>
        category switch
        {
            PersonalTaskCategory.School => "school",
            PersonalTaskCategory.Apprenticeship => "apprenticeship",
            PersonalTaskCategory.Company => "company",
            _ => "school"
        };

    private static string ToEventCategoryName(PersonalEventCategory category) =>
        category switch
        {
            PersonalEventCategory.Apprenticeship => "apprenticeship",
            PersonalEventCategory.Company => "company",
            PersonalEventCategory.Personnel => "personal",
            _ => "personal"
        };

    private async Task<ApplicationUser?> CurrentUserAsync() =>
        await userManager.FindByIdAsync(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    private sealed record CourseProtectedData(TimeOnly StartsAt, TimeOnly EndsAt, string Room);
    private sealed record PersonalEventProtectedData(
        string Title,
        TimeOnly StartsAt,
        TimeOnly EndsAt,
        string? Location,
        string? Notes);
}
