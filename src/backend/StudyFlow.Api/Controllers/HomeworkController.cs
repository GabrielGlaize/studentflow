using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StudyFlow.Api.Contracts;
using StudyFlow.Application.Security;
using StudyFlow.Domain.Contributions;
using StudyFlow.Domain.School;
using StudyFlow.Infrastructure.Identity;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/homework")]
public sealed class HomeworkController(
    UserManager<ApplicationUser> userManager,
    StudyFlowDbContext dbContext,
    ISensitiveDataProtector protector) : StudyFlowControllerBase(userManager)
{
    private const string RevisionPurpose = "revision-contribution";
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    [HttpGet]
    public async Task<ActionResult<IReadOnlyCollection<HomeworkResponse>>> List(
        [FromQuery] bool includeDone = false,
        CancellationToken cancellationToken = default)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var homeworkItems = await dbContext.HomeworkItems
            .AsNoTracking()
            .Include(x => x.ProgressItems.Where(progress => progress.UserId == user.Id))
            .Include(x => x.Course).ThenInclude(course => course!.Subject)
            .Where(x => x.SchoolClassId == user.SchoolClassId && x.DeletedAt == null)
            .OrderBy(x => x.Deadline)
            .ToListAsync(cancellationToken);

        var visibleHomework = homeworkItems
            .Where(x => includeDone || x.ProgressItems.SingleOrDefault()?.IsDone != true)
            .Select(ToResponse)
            .ToArray();

        return Ok(visibleHomework);
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<HomeworkResponse>> GetById(Guid id, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var homework = await dbContext.HomeworkItems
            .AsNoTracking()
            .Include(x => x.ProgressItems.Where(progress => progress.UserId == user.Id))
            .Include(x => x.Course).ThenInclude(course => course!.Subject)
            .SingleOrDefaultAsync(x => x.Id == id
                && x.SchoolClassId == user.SchoolClassId
                && x.DeletedAt == null, cancellationToken);

        return homework is null ? NotFound() : Ok(ToResponse(homework));
    }

    [HttpPost]
    public async Task<ActionResult<HomeworkResponse>> Create(
        HomeworkRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var validationProblem = await ValidateRequestAsync(user.SchoolClassId.Value, request.Title, request.CourseId, cancellationToken);
        if (validationProblem is not null) return validationProblem;

        var homework = new Homework
        {
            SchoolClassId = user.SchoolClassId.Value,
            CourseId = request.CourseId,
            Title = request.Title.Trim(),
            Description = string.IsNullOrWhiteSpace(request.Description) ? null : request.Description.Trim(),
            Deadline = request.Deadline.ToUniversalTime(),
            IsEvaluation = request.IsEvaluation,
            IsGroupWork = request.IsGroupWork,
            CreatedById = user.Id
        };

        dbContext.HomeworkItems.Add(homework);
        await dbContext.SaveChangesAsync(cancellationToken);
        await SaveRevisionAsync(user, ContributionAction.Created, homework, cancellationToken);
        await LoadCourseAsync(homework, cancellationToken);

        return CreatedAtAction(nameof(GetById), new { id = homework.Id }, ToResponse(homework));
    }

    [HttpPut("{id:guid}")]
    public async Task<ActionResult<HomeworkResponse>> Update(
        Guid id,
        HomeworkUpdateRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var homework = await dbContext.HomeworkItems
            .SingleOrDefaultAsync(x => x.Id == id
                && x.SchoolClassId == user.SchoolClassId
                && x.DeletedAt == null, cancellationToken);
        if (homework is null) return NotFound();

        var validationProblem = await ValidateRequestAsync(user.SchoolClassId.Value, request.Title, request.CourseId, cancellationToken);
        if (validationProblem is not null) return validationProblem;

        homework.CourseId = request.CourseId;
        homework.Title = request.Title.Trim();
        homework.Description = string.IsNullOrWhiteSpace(request.Description) ? null : request.Description.Trim();
        homework.Deadline = request.Deadline.ToUniversalTime();
        homework.IsEvaluation = request.IsEvaluation;
        homework.IsGroupWork = request.IsGroupWork;
        homework.UpdatedAt = DateTimeOffset.UtcNow;
        homework.UpdatedById = user.Id;

        await dbContext.SaveChangesAsync(cancellationToken);
        await SaveRevisionAsync(user, ContributionAction.Updated, homework, cancellationToken);
        await LoadCurrentUserProgressAsync(homework, user.Id, cancellationToken);
        await LoadCourseAsync(homework, cancellationToken);

        return Ok(ToResponse(homework));
    }

    [HttpPut("{id:guid}/progress")]
    public async Task<ActionResult<HomeworkResponse>> UpdateProgress(
        Guid id,
        HomeworkProgressRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var homework = await dbContext.HomeworkItems
            .SingleOrDefaultAsync(x => x.Id == id
                && x.SchoolClassId == user.SchoolClassId
                && x.DeletedAt == null, cancellationToken);
        if (homework is null) return NotFound();
        if (request.ReminderMinutesBefore is { } minutes && !ReminderDefaults.IsValid(minutes))
        {
            return BadRequestProblem("Le rappel doit être programmé entre le moment même et 30 jours avant.");
        }

        var progress = await dbContext.HomeworkProgressItems
            .SingleOrDefaultAsync(x => x.HomeworkId == id && x.UserId == user.Id, cancellationToken);

        var now = DateTimeOffset.UtcNow;
        if (progress is null)
        {
            progress = new HomeworkProgress
            {
                HomeworkId = id,
                UserId = user.Id
            };
            dbContext.HomeworkProgressItems.Add(progress);
        }

        progress.IsDone = request.IsDone;
        progress.NotificationsEnabled = request.NotificationsEnabled;
        if (request.ReminderMinutesBefore is { } reminder) progress.ReminderMinutesBefore = reminder;
        progress.CompletedAt = request.IsDone
            ? progress.CompletedAt ?? now
            : null;

        await dbContext.SaveChangesAsync(cancellationToken);
        await LoadCurrentUserProgressAsync(homework, user.Id, cancellationToken);
        await LoadCourseAsync(homework, cancellationToken);

        return Ok(ToResponse(homework));
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var homework = await dbContext.HomeworkItems
            .SingleOrDefaultAsync(x => x.Id == id
                && x.SchoolClassId == user.SchoolClassId
                && x.DeletedAt == null, cancellationToken);
        if (homework is null) return NotFound();

        homework.DeletedAt = DateTimeOffset.UtcNow;
        homework.UpdatedAt = DateTimeOffset.UtcNow;
        homework.UpdatedById = user.Id;

        await dbContext.SaveChangesAsync(cancellationToken);
        await SaveRevisionAsync(user, ContributionAction.Deleted, homework, cancellationToken);
        return NoContent();
    }

    private async Task<ActionResult?> ValidateRequestAsync(
        Guid schoolClassId,
        string title,
        Guid? courseId,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(title))
        {
            return BadRequestProblem("Le titre du devoir est obligatoire.");
        }

        // Un devoir est toujours rattaché au cours pour lequel il est à faire : c'est ce qui
        // permet d'afficher sa matière et de le retrouver depuis le planning.
        if (courseId is null)
        {
            return BadRequestProblem("Choisis le cours pour lequel ce devoir est à faire.");
        }

        {
            var courseExists = await dbContext.Courses.AnyAsync(
                x => x.Id == courseId
                    && x.SchoolClassId == schoolClassId
                    && x.DeletedAt == null,
                cancellationToken);
            if (!courseExists) return BadRequestProblem("Le cours lié au devoir n'existe pas dans votre classe.");
        }

        return null;
    }

    private static HomeworkResponse ToResponse(Homework homework) => new(
        homework.Id,
        homework.Title,
        homework.Description,
        homework.Deadline,
        homework.CourseId,
        homework.Course?.Subject.Name,
        homework.Course?.Day,
        homework.ProgressItems.SingleOrDefault()?.IsDone ?? false,
        homework.ProgressItems.SingleOrDefault()?.NotificationsEnabled ?? true,
        homework.ProgressItems.SingleOrDefault()?.CompletedAt,
        homework.CreatedAt,
        homework.UpdatedAt,
        homework.ProgressItems.SingleOrDefault()?.ReminderMinutesBefore ?? ReminderDefaults.HomeworkMinutes,
        homework.IsEvaluation,
        homework.IsGroupWork);

    private async Task LoadCourseAsync(Homework homework, CancellationToken cancellationToken)
    {
        if (homework.CourseId is null) return;

        await dbContext.Entry(homework).Reference(x => x.Course).LoadAsync(cancellationToken);
        if (homework.Course is not null)
        {
            await dbContext.Entry(homework.Course).Reference(x => x.Subject).LoadAsync(cancellationToken);
        }
    }

    private async Task LoadCurrentUserProgressAsync(
        Homework homework,
        Guid userId,
        CancellationToken cancellationToken)
    {
        // Only the current student's progress is returned; the class homework stays shared.
        await dbContext.Entry(homework)
            .Collection(x => x.ProgressItems)
            .Query()
            .Where(progress => progress.UserId == userId)
            .LoadAsync(cancellationToken);
    }

    private async Task SaveRevisionAsync(
        ApplicationUser user,
        ContributionAction action,
        Homework homework,
        CancellationToken cancellationToken)
    {
        // Les revisions donnent un historique simple des apports de la classe.
        var snapshot = JsonSerializer.Serialize(new
        {
            homework.Id,
            homework.Title,
            homework.Description,
            homework.Deadline,
            homework.CourseId,
            homework.UpdatedAt
        }, JsonOptions);

        dbContext.ContributionRevisions.Add(new ContributionRevision
        {
            SchoolClassId = user.SchoolClassId!.Value,
            EntityType = ContributionType.Homework,
            EntityId = homework.Id,
            Action = action,
            AuthorId = user.Id,
            EncryptedSnapshot = protector.Protect(snapshot, RevisionPurpose)
        });

        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
