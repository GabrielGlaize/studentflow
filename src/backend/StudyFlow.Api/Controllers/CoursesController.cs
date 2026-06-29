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
[Route("api/v1/courses")]
public sealed class CoursesController(
    UserManager<ApplicationUser> userManager,
    StudyFlowDbContext dbContext,
    ISensitiveDataProtector protector) : ControllerBase
{
    private const string CourseDataPurpose = "course-data";
    private const string ProfessorDisplayPurpose = "teacher-display-name";
    private const string RevisionPurpose = "revision-contribution";

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    [HttpGet]
    public async Task<ActionResult<IReadOnlyCollection<CourseResponse>>> List(
        [FromQuery] DateOnly? from,
        [FromQuery] DateOnly? to,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var start = from ?? DateOnly.FromDateTime(DateTime.Today.AddDays(-7));
        var end = to ?? DateOnly.FromDateTime(DateTime.Today.AddDays(21));
        if (end < start) return BadRequestProblem("La date de fin doit etre apres la date de debut.");

        var course = await dbContext.Courses
            .AsNoTracking()
            .Include(x => x.Subject)
            .Include(x => x.Teacher)
            .Where(x => x.SchoolClassId == user.SchoolClassId
                && x.DeletedAt == null
                && x.Day >= start
                && x.Day <= end)
            .OrderBy(x => x.Day)
            .ToListAsync(cancellationToken);

        return Ok(course.Select(ToResponse).OrderBy(x => x.Day).ThenBy(x => x.StartsAt).ToArray());
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<CourseResponse>> GetById(Guid id, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var course = await dbContext.Courses
            .AsNoTracking()
            .Include(x => x.Subject)
            .Include(x => x.Teacher)
            .SingleOrDefaultAsync(x => x.Id == id
                && x.SchoolClassId == user.SchoolClassId
                && x.DeletedAt == null, cancellationToken);

        return course is null ? NotFound() : Ok(ToResponse(course));
    }

    [HttpPost]
    public async Task<ActionResult<CourseResponse>> Create(CourseRequest request, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var validationProblem = await ValidateCourseRequestAsync(
            user.SchoolClassId.Value,
            request.SubjectId,
            request.TeacherId,
            request.Day,
            request.StartsAt,
            request.EndsAt,
            request.Room,
            request.IsCancelled,
            excludedCourseId: null,
            cancellationToken);
        if (validationProblem is not null) return validationProblem;

        var course = new Course
        {
            SchoolClassId = user.SchoolClassId.Value,
            SeriesId = request.SeriesId,
            SubjectId = request.SubjectId,
            TeacherId = request.TeacherId,
            Day = request.Day,
            EncryptedData = ProtectCourseData(request.StartsAt, request.EndsAt, request.Room),
            IsCancelled = request.IsCancelled,
            CreatedById = user.Id
        };

        dbContext.Courses.Add(course);
        await dbContext.SaveChangesAsync(cancellationToken);

        await SaveRevisionAsync(user, ContributionAction.Created, course, cancellationToken);
        await dbContext.Entry(course).Reference(x => x.Subject).LoadAsync(cancellationToken);
        await dbContext.Entry(course).Reference(x => x.Teacher).LoadAsync(cancellationToken);

        return CreatedAtAction(nameof(GetById), new { id = course.Id }, ToResponse(course));
    }

    [HttpPut("{id:guid}")]
    public async Task<ActionResult<CourseResponse>> Update(
        Guid id,
        CourseUpdateRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var course = await dbContext.Courses
            .Include(x => x.Subject)
            .Include(x => x.Teacher)
            .SingleOrDefaultAsync(x => x.Id == id
                && x.SchoolClassId == user.SchoolClassId
                && x.DeletedAt == null, cancellationToken);
        if (course is null) return NotFound();

        // La version evite d'ecraser sans le savoir une modification faite par un autre eleve.
        if (course.Version != request.Version)
        {
            return Conflict(new ProblemDetails
            {
                Title = "Le cours a deja ete modifie par quelqu'un d'autre.",
                Detail = "Rechargez le cours avant de le modifier.",
                Status = StatusCodes.Status409Conflict
            });
        }

        var validationProblem = await ValidateCourseRequestAsync(
            user.SchoolClassId.Value,
            request.SubjectId,
            request.TeacherId,
            request.Day,
            request.StartsAt,
            request.EndsAt,
            request.Room,
            request.IsCancelled,
            excludedCourseId: course.Id,
            cancellationToken);
        if (validationProblem is not null) return validationProblem;

        course.SeriesId = request.SeriesId;
        course.SubjectId = request.SubjectId;
        course.TeacherId = request.TeacherId;
        course.Day = request.Day;
        course.EncryptedData = ProtectCourseData(request.StartsAt, request.EndsAt, request.Room);
        course.IsCancelled = request.IsCancelled;
        course.UpdatedAt = DateTimeOffset.UtcNow;
        course.UpdatedById = user.Id;
        course.Version++;

        await dbContext.SaveChangesAsync(cancellationToken);
        await SaveRevisionAsync(user, ContributionAction.Updated, course, cancellationToken);
        await dbContext.Entry(course).Reference(x => x.Subject).LoadAsync(cancellationToken);
        await dbContext.Entry(course).Reference(x => x.Teacher).LoadAsync(cancellationToken);

        return Ok(ToResponse(course));
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var course = await dbContext.Courses
            .SingleOrDefaultAsync(x => x.Id == id
                && x.SchoolClassId == user.SchoolClassId
                && x.DeletedAt == null, cancellationToken);
        if (course is null) return NotFound();

        course.DeletedAt = DateTimeOffset.UtcNow;
        course.UpdatedAt = DateTimeOffset.UtcNow;
        course.UpdatedById = user.Id;
        course.Version++;

        await dbContext.SaveChangesAsync(cancellationToken);
        await SaveRevisionAsync(user, ContributionAction.Deleted, course, cancellationToken);
        return NoContent();
    }

    [HttpGet("{id:guid}/revisions")]
    public async Task<ActionResult<IReadOnlyCollection<CourseRevisionResponse>>> Revisions(
        Guid id,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var courseExists = await dbContext.Courses
            .IgnoreQueryFilters()
            .AnyAsync(x => x.Id == id && x.SchoolClassId == user.SchoolClassId, cancellationToken);
        if (!courseExists) return NotFound();

        var revisions = await (
            from revision in dbContext.ContributionRevisions.AsNoTracking()
            join author in dbContext.Users.AsNoTracking() on revision.AuthorId equals author.Id
            where revision.SchoolClassId == user.SchoolClassId
                && revision.EntityType == ContributionType.Course
                && revision.EntityId == id
            orderby revision.CreatedAt descending
            select new { revision, author })
            .ToListAsync(cancellationToken);

        return Ok(revisions.Select(x =>
        {
            var snapshot = ReadRevisionSnapshot(x.revision);
            return new CourseRevisionResponse(
                x.revision.Id,
                x.revision.Action.ToString(),
                $"{x.author.FirstName} {x.author.LastName}".Trim(),
                x.revision.CreatedAt,
                snapshot.Version);
        }).ToArray());
    }

    [HttpPost("{id:guid}/restore-latest")]
    public async Task<ActionResult<CourseResponse>> RestoreLatest(Guid id, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var course = await dbContext.Courses
            .IgnoreQueryFilters()
            .Include(x => x.Subject)
            .Include(x => x.Teacher)
            .SingleOrDefaultAsync(x => x.Id == id && x.SchoolClassId == user.SchoolClassId, cancellationToken);
        if (course is null) return NotFound();

        var revision = await dbContext.ContributionRevisions
            .AsNoTracking()
            .Where(x => x.SchoolClassId == user.SchoolClassId
                && x.EntityType == ContributionType.Course
                && x.EntityId == id)
            .OrderByDescending(x => x.CreatedAt)
            .FirstOrDefaultAsync(cancellationToken);
        if (revision is null) return NotFound();

        var snapshot = ReadRevisionSnapshot(revision);
        course.SubjectId = snapshot.SubjectId;
        course.TeacherId = snapshot.TeacherId;
        course.Day = snapshot.Day;
        course.IsCancelled = snapshot.IsCancelled;
        course.EncryptedData = snapshot.EncryptedData;
        course.DeletedAt = null;
        course.UpdatedAt = DateTimeOffset.UtcNow;
        course.UpdatedById = user.Id;
        course.Version++;

        await dbContext.SaveChangesAsync(cancellationToken);
        await SaveRevisionAsync(user, ContributionAction.Restored, course, cancellationToken);
        await dbContext.Entry(course).Reference(x => x.Subject).LoadAsync(cancellationToken);
        await dbContext.Entry(course).Reference(x => x.Teacher).LoadAsync(cancellationToken);

        return Ok(ToResponse(course));
    }

    private async Task<ActionResult?> ValidateCourseRequestAsync(
        Guid schoolClassId,
        Guid subjectId,
        Guid? teacherId,
        DateOnly day,
        TimeOnly startsAt,
        TimeOnly endsAt,
        string room,
        bool isCancelled,
        Guid? excludedCourseId,
        CancellationToken cancellationToken)
    {
        if (endsAt <= startsAt)
        {
            return BadRequestProblem("L'heure de fin doit etre apres l'heure de debut.");
        }

        if (string.IsNullOrWhiteSpace(room))
        {
            return BadRequestProblem("La salle est obligatoire.");
        }

        var matiereExists = await dbContext.Subjects.AnyAsync(
            x => x.Id == subjectId && x.SchoolClassId == schoolClassId && x.IsActive,
            cancellationToken);
        if (!matiereExists) return BadRequestProblem("La matiere n'existe pas dans votre classe.");

        if (teacherId is not null)
        {
            var teacherExists = await dbContext.Teachers.AnyAsync(
                x => x.Id == teacherId && x.SchoolClassId == schoolClassId && x.IsActive,
                cancellationToken);
            if (!teacherExists) return BadRequestProblem("Le professeur n'existe pas dans votre classe.");
        }

        if (!isCancelled)
        {
            var coursesSameDay = await dbContext.Courses
                .AsNoTracking()
                .Where(x => x.SchoolClassId == schoolClassId
                    && x.Day == day
                    && !x.IsCancelled
                    && x.Id != excludedCourseId)
                .ToListAsync(cancellationToken);

            var hasConflict = coursesSameDay.Any(course =>
            {
                var data = JsonSerializer.Deserialize<CourseProtectedData>(
                    protector.Unprotect(course.EncryptedData, CourseDataPurpose),
                    JsonOptions)!;
                return startsAt < data.EndsAt && endsAt > data.StartsAt;
            });

            if (hasConflict)
            {
                return Conflict(new ProblemDetails
                {
                    Title = "Ce cours chevauche deja un autre cours.",
                    Detail = "Corrigez l'horaire ou modifiez le cours existant.",
                    Status = StatusCodes.Status409Conflict
                });
            }
        }

        return null;
    }

    private CourseResponse ToResponse(Course course)
    {
        var data = JsonSerializer.Deserialize<CourseProtectedData>(
            protector.Unprotect(course.EncryptedData, CourseDataPurpose),
            JsonOptions)!;

        return new CourseResponse(
            course.Id,
            course.SubjectId,
            course.Subject.Name,
            course.TeacherId,
            course.Teacher is null ? null : protector.Unprotect(course.Teacher.EncryptedDisplayName, ProfessorDisplayPurpose),
            course.Day,
            data.StartsAt,
            data.EndsAt,
            data.Room,
            course.IsCancelled,
            course.Version);
    }

    private string ProtectCourseData(TimeOnly startsAt, TimeOnly endsAt, string room)
    {
        // Les horaires precis, les salles et les professeurs sont sensibles : on garde ces details chiffres en base.
        var data = new CourseProtectedData(startsAt, endsAt, room.Trim());
        return protector.Protect(JsonSerializer.Serialize(data, JsonOptions), CourseDataPurpose);
    }

    private async Task SaveRevisionAsync(
        ApplicationUser user,
        ContributionAction action,
        Course course,
        CancellationToken cancellationToken)
    {
        // Le journal permet de comprendre qui a modifie quoi, sans rendre obligatoire une validation par delegue.
        var snapshot = JsonSerializer.Serialize(new
        {
            course.Id,
            course.SubjectId,
            course.TeacherId,
            course.Day,
            course.IsCancelled,
            course.Version,
            course.EncryptedData
        }, JsonOptions);

        dbContext.ContributionRevisions.Add(new ContributionRevision
        {
            SchoolClassId = user.SchoolClassId!.Value,
            EntityType = ContributionType.Course,
            EntityId = course.Id,
            Action = action,
            AuthorId = user.Id,
            EncryptedSnapshot = protector.Protect(snapshot, RevisionPurpose)
        });

        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task<ApplicationUser?> CurrentUserAsync() =>
        await userManager.FindByIdAsync(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    private RevisionCourseSnapshot ReadRevisionSnapshot(ContributionRevision revision)
    {
        return JsonSerializer.Deserialize<RevisionCourseSnapshot>(
            protector.Unprotect(revision.EncryptedSnapshot, RevisionPurpose),
            JsonOptions)!;
    }

    private ObjectResult BadRequestProblem(string title) =>
        BadRequest(new ProblemDetails { Title = title, Status = StatusCodes.Status400BadRequest });

    private sealed record CourseProtectedData(TimeOnly StartsAt, TimeOnly EndsAt, string Room);

    private sealed record RevisionCourseSnapshot(
        Guid Id,
        Guid SubjectId,
        Guid? TeacherId,
        DateOnly Day,
        bool IsCancelled,
        long Version,
        string EncryptedData);
}
