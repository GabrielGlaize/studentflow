using System.Security.Claims;
using System.Security.Cryptography;
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
[Route("api/v1/class-resources")]
public sealed class ClassResourcesController(
    UserManager<ApplicationUser> userManager,
    StudyFlowDbContext dbContext,
    ISensitiveDataProtector protector) : ControllerBase
{
    private const string ProfessorDisplayPurpose = "teacher-display-name";
    private const string ProfessorLookupPurpose = "teacher-search-name";
    private const string ProfessorInfoPurpose = "teacher-information";

    [HttpGet("subjects")]
    public async Task<ActionResult<IReadOnlyCollection<SubjectResponse>>> ListSubjects(CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var subjects = await dbContext.Subjects
            .AsNoTracking()
            .Where(x => x.SchoolClassId == user.SchoolClassId && x.IsActive)
            .OrderBy(x => x.Name)
            .Select(x => new SubjectResponse(x.Id, x.Name, x.IsActive))
            .ToListAsync(cancellationToken);

        return Ok(subjects);
    }

    [HttpPost("subjects")]
    public async Task<ActionResult<SubjectResponse>> CreateSubject(SubjectRequest request, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var name = request.Name.Trim();
        if (string.IsNullOrWhiteSpace(name)) return BadRequestProblem("Le nom de la matiere est obligatoire.");

        var exists = await dbContext.Subjects.AnyAsync(
            x => x.SchoolClassId == user.SchoolClassId && x.Name == name,
            cancellationToken);
        if (exists) return ConflictProblem("Cette matiere existe deja dans la classe.");

        var subject = new Subject
        {
            SchoolClassId = user.SchoolClassId.Value,
            Name = name,
            CreatedById = user.Id
        };

        dbContext.Subjects.Add(subject);
        await dbContext.SaveChangesAsync(cancellationToken);

        return CreatedAtAction(nameof(ListSubjects), new SubjectResponse(subject.Id, subject.Name, subject.IsActive));
    }

    [HttpDelete("subjects/{id:guid}")]
    public async Task<IActionResult> DeleteSubject(Guid id, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var subject = await dbContext.Subjects.SingleOrDefaultAsync(
            x => x.Id == id && x.SchoolClassId == user.SchoolClassId,
            cancellationToken);
        if (subject is null) return NotFound();

        subject.IsActive = false;
        await dbContext.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    [HttpGet("teachers")]
    public async Task<ActionResult<IReadOnlyCollection<TeacherResponse>>> ListTeachers(CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var teachers = await dbContext.Teachers
            .AsNoTracking()
            .Where(x => x.SchoolClassId == user.SchoolClassId && x.IsActive)
            .OrderBy(x => x.CreatedAt)
            .ToListAsync(cancellationToken);

        var responses = teachers
            .Select(TryToResponse)
            .OfType<TeacherResponse>()
            .ToArray();

        return Ok(responses);
    }

    [HttpPost("teachers")]
    public async Task<ActionResult<TeacherResponse>> CreateTeacher(
        TeacherRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var displayName = request.DisplayName.Trim();
        if (string.IsNullOrWhiteSpace(displayName)) return BadRequestProblem("Le nom du professeur est obligatoire.");

        // Le nom du professeur sert a detecter les doublons, mais il n'est jamais stocke en clair.
        var lookupHash = protector.ComputeLookupHash(displayName, ProfessorLookupPurpose);
        var exists = await dbContext.Teachers.AnyAsync(
            x => x.SchoolClassId == user.SchoolClassId && x.SearchNameHash == lookupHash,
            cancellationToken);
        if (exists) return ConflictProblem("Ce professeur existe deja dans la classe.");

        var teacher = new Teacher
        {
            SchoolClassId = user.SchoolClassId.Value,
            EncryptedDisplayName = protector.Protect(displayName, ProfessorDisplayPurpose),
            SearchNameHash = lookupHash,
            EncryptedInformation = ProtectOptional(request.Information, ProfessorInfoPurpose),
            CreatedById = user.Id
        };

        dbContext.Teachers.Add(teacher);
        await dbContext.SaveChangesAsync(cancellationToken);

        return CreatedAtAction(nameof(ListTeachers), ToResponse(teacher));
    }

    [HttpDelete("teachers/{id:guid}")]
    public async Task<IActionResult> DeleteTeacher(Guid id, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var teacher = await dbContext.Teachers.SingleOrDefaultAsync(
            x => x.Id == id && x.SchoolClassId == user.SchoolClassId,
            cancellationToken);
        if (teacher is null) return NotFound();

        teacher.IsActive = false;
        await dbContext.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    private TeacherResponse ToResponse(Teacher teacher) => new(
        teacher.Id,
        protector.Unprotect(teacher.EncryptedDisplayName, ProfessorDisplayPurpose),
        UnprotectOptional(teacher.EncryptedInformation, ProfessorInfoPurpose),
        teacher.IsActive);

    private TeacherResponse? TryToResponse(Teacher teacher)
    {
        try
        {
            return ToResponse(teacher);
        }
        catch (CryptographicException)
        {
            // Local development databases can contain old encrypted demo rows after a key
            // change. We skip unreadable rows instead of breaking the whole resource screen.
            return null;
        }
    }

    private async Task<ApplicationUser?> CurrentUserAsync() =>
        await userManager.FindByIdAsync(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    private string? ProtectOptional(string? value, string purpose) =>
        string.IsNullOrWhiteSpace(value) ? null : protector.Protect(value.Trim(), purpose);

    private string? UnprotectOptional(string? value, string purpose) =>
        string.IsNullOrWhiteSpace(value) ? null : protector.Unprotect(value, purpose);

    private ObjectResult ConflictProblem(string title) =>
        Conflict(new ProblemDetails { Title = title, Status = StatusCodes.Status409Conflict });

    private ObjectResult BadRequestProblem(string title) =>
        BadRequest(new ProblemDetails { Title = title, Status = StatusCodes.Status400BadRequest });
}
