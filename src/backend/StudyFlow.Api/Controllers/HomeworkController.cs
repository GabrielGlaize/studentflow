using System.Security.Claims;
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
    ISensitiveDataProtector protector) : ControllerBase
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
            Deadline = request.Deadline,
            CreatedById = user.Id
        };

        dbContext.HomeworkItems.Add(homework);
        await dbContext.SaveChangesAsync(cancellationToken);
        await SaveRevisionAsync(user, ContributionAction.Created, homework, cancellationToken);

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
        homework.Deadline = request.Deadline;
        homework.UpdatedAt = DateTimeOffset.UtcNow;
        homework.UpdatedById = user.Id;

        await dbContext.SaveChangesAsync(cancellationToken);
        await SaveRevisionAsync(user, ContributionAction.Updated, homework, cancellationToken);
        await LoadCurrentUserProgressAsync(homework, user.Id, cancellationToken);

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
        progress.CompletedAt = request.IsDone
            ? progress.CompletedAt ?? now
            : null;

        await dbContext.SaveChangesAsync(cancellationToken);
        await LoadCurrentUserProgressAsync(homework, user.Id, cancellationToken);

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

        if (courseId is not null)
        {
            var courseExists = await dbContext.Courses.AnyAsync(
                x => x.Id == courseId
                    && x.SchoolClassId == schoolClassId
                    && x.DeletedAt == null,
                cancellationToken);
            if (!courseExists) return BadRequestProblem("Le cours lie au devoir n'existe pas dans votre classe.");
        }

        return null;
    }

    private static HomeworkResponse ToResponse(Homework homework) => new(
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

    private async Task<ApplicationUser?> CurrentUserAsync() =>
        await userManager.FindByIdAsync(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    private ObjectResult BadRequestProblem(string title) =>
        BadRequest(new ProblemDetails { Title = title, Status = StatusCodes.Status400BadRequest });
}
