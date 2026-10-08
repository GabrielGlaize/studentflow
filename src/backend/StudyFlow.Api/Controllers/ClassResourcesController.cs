using System.Security.Cryptography;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StudyFlow.Api.Contracts;
using StudyFlow.Application.Security;
using StudyFlow.Domain.School;
using StudyFlow.Domain.Users;
using StudyFlow.Infrastructure.Identity;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Api.Controllers;

// Lecture pour toute la classe ; la gestion des listes communes est réservée aux délégués.
// Une matière ou un intervenant supprimé est seulement désactivé (les anciens cours y restent
// rattachés) : le recréer sous le même nom le réactive au lieu de signaler un doublon.
[ApiController]
[Authorize]
[Route("api/v1/class-resources")]
public sealed class ClassResourcesController(
    UserManager<ApplicationUser> userManager,
    StudyFlowDbContext dbContext,
    ISensitiveDataProtector protector) : StudyFlowControllerBase(userManager)
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
            .Select(x => new SubjectResponse(
                x.Id,
                x.Name,
                x.IsActive,
                x.TeacherLinks.Where(link => link.Teacher.IsActive).Select(link => link.TeacherId).ToList()))
            .ToListAsync(cancellationToken);

        return Ok(subjects);
    }

    [Authorize(Roles = nameof(UserRole.Delegue))]
    [HttpPost("subjects")]
    public async Task<ActionResult<SubjectResponse>> CreateSubject(SubjectRequest request, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();
        var classId = user.SchoolClassId.Value;

        var name = request.Name.Trim();
        if (string.IsNullOrWhiteSpace(name)) return BadRequestProblem("Le nom de la matière est obligatoire.");

        var sameName = await dbContext.Subjects
            .Where(x => x.SchoolClassId == classId && x.Name.ToLower() == name.ToLower())
            .OrderByDescending(x => x.IsActive)
            .FirstOrDefaultAsync(cancellationToken);
        if (sameName?.IsActive == true) return ConflictProblem($"La matière « {sameName.Name} » existe déjà dans la classe.");

        var teacherIds = await ActiveTeacherIdsAsync(classId, request.TeacherIds, cancellationToken);
        if (teacherIds is null) return BadRequestProblem("Un des intervenants choisis n'existe pas dans votre classe.");

        var subject = sameName ?? new Subject { SchoolClassId = classId, CreatedById = user.Id };
        subject.Name = name;
        subject.IsActive = true;
        if (sameName is null) dbContext.Subjects.Add(subject);

        await ReplaceSubjectLinksAsync(subject.Id, teacherIds, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);

        return CreatedAtAction(nameof(ListSubjects), new SubjectResponse(subject.Id, subject.Name, subject.IsActive, teacherIds));
    }

    [Authorize(Roles = nameof(UserRole.Delegue))]
    [HttpPut("subjects/{id:guid}")]
    public async Task<ActionResult<SubjectResponse>> UpdateSubject(
        Guid id,
        SubjectRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();
        var classId = user.SchoolClassId.Value;

        var subject = await dbContext.Subjects.SingleOrDefaultAsync(
            x => x.Id == id && x.SchoolClassId == classId && x.IsActive,
            cancellationToken);
        if (subject is null) return NotFound();

        var name = request.Name.Trim();
        if (string.IsNullOrWhiteSpace(name)) return BadRequestProblem("Le nom de la matière est obligatoire.");

        var nameTaken = await dbContext.Subjects.AnyAsync(
            x => x.SchoolClassId == classId && x.IsActive && x.Id != id && x.Name.ToLower() == name.ToLower(),
            cancellationToken);
        if (nameTaken) return ConflictProblem("Une autre matière porte déjà ce nom.");

        var teacherIds = await ActiveTeacherIdsAsync(classId, request.TeacherIds, cancellationToken);
        if (teacherIds is null) return BadRequestProblem("Un des intervenants choisis n'existe pas dans votre classe.");

        subject.Name = name;
        await ReplaceSubjectLinksAsync(subject.Id, teacherIds, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);

        return Ok(new SubjectResponse(subject.Id, subject.Name, subject.IsActive, teacherIds));
    }

    [Authorize(Roles = nameof(UserRole.Delegue))]
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
            .Include(x => x.SubjectLinks.Where(link => link.Subject.IsActive))
            .Where(x => x.SchoolClassId == user.SchoolClassId && x.IsActive)
            .ToListAsync(cancellationToken);

        var responses = teachers
            .Select(TryToResponse)
            .OfType<TeacherResponse>()
            .OrderBy(x => SortableName(x.DisplayName), StringComparer.CurrentCultureIgnoreCase)
            .ToArray();

        return Ok(responses);
    }

    [Authorize(Roles = nameof(UserRole.Delegue))]
    [HttpPost("teachers")]
    public async Task<ActionResult<TeacherResponse>> CreateTeacher(
        TeacherRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();
        var classId = user.SchoolClassId.Value;

        var displayName = request.DisplayName.Trim();
        if (string.IsNullOrWhiteSpace(displayName)) return BadRequestProblem("Le nom de l'intervenant est obligatoire.");

        // Le nom de l'intervenant sert à détecter les doublons, mais il n'est jamais stocké en clair.
        var lookupHash = protector.ComputeLookupHash(displayName, ProfessorLookupPurpose);
        var sameName = await dbContext.Teachers
            .Where(x => x.SchoolClassId == classId && x.SearchNameHash == lookupHash)
            .OrderByDescending(x => x.IsActive)
            .FirstOrDefaultAsync(cancellationToken);
        if (sameName?.IsActive == true) return ConflictProblem($"L'intervenant « {displayName} » existe déjà dans la classe.");

        var subjectIds = await ActiveSubjectIdsAsync(classId, request.SubjectIds, cancellationToken);
        if (subjectIds is null) return BadRequestProblem("Une des matières choisies n'existe pas dans votre classe.");

        var teacher = sameName ?? new Teacher { SchoolClassId = classId, CreatedById = user.Id };
        teacher.EncryptedDisplayName = protector.Protect(displayName, ProfessorDisplayPurpose);
        teacher.SearchNameHash = lookupHash;
        teacher.EncryptedInformation = ProtectOptional(request.Information, ProfessorInfoPurpose);
        teacher.IsActive = true;
        if (sameName is null) dbContext.Teachers.Add(teacher);

        await ReplaceTeacherLinksAsync(teacher.Id, subjectIds, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);

        return CreatedAtAction(nameof(ListTeachers), ToResponse(teacher, subjectIds));
    }

    [Authorize(Roles = nameof(UserRole.Delegue))]
    [HttpPut("teachers/{id:guid}")]
    public async Task<ActionResult<TeacherResponse>> UpdateTeacher(
        Guid id,
        TeacherRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();
        var classId = user.SchoolClassId.Value;

        var teacher = await dbContext.Teachers.SingleOrDefaultAsync(
            x => x.Id == id && x.SchoolClassId == classId && x.IsActive,
            cancellationToken);
        if (teacher is null) return NotFound();

        var displayName = request.DisplayName.Trim();
        if (string.IsNullOrWhiteSpace(displayName)) return BadRequestProblem("Le nom de l'intervenant est obligatoire.");

        var lookupHash = protector.ComputeLookupHash(displayName, ProfessorLookupPurpose);
        var nameTaken = await dbContext.Teachers.AnyAsync(
            x => x.SchoolClassId == classId && x.IsActive && x.Id != id && x.SearchNameHash == lookupHash,
            cancellationToken);
        if (nameTaken) return ConflictProblem("Un autre intervenant porte déjà ce nom.");

        var subjectIds = await ActiveSubjectIdsAsync(classId, request.SubjectIds, cancellationToken);
        if (subjectIds is null) return BadRequestProblem("Une des matières choisies n'existe pas dans votre classe.");

        teacher.EncryptedDisplayName = protector.Protect(displayName, ProfessorDisplayPurpose);
        teacher.SearchNameHash = lookupHash;
        teacher.EncryptedInformation = ProtectOptional(request.Information, ProfessorInfoPurpose);

        await ReplaceTeacherLinksAsync(teacher.Id, subjectIds, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);

        return Ok(ToResponse(teacher, subjectIds));
    }

    [Authorize(Roles = nameof(UserRole.Delegue))]
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

    /// <summary>Renvoie les identifiants dédoublonnés, ou <c>null</c> si l'un d'eux n'est pas une matière active de la classe.</summary>
    private async Task<IReadOnlyCollection<Guid>?> ActiveSubjectIdsAsync(
        Guid classId,
        IReadOnlyCollection<Guid>? requested,
        CancellationToken cancellationToken)
    {
        var ids = (requested ?? []).Distinct().ToArray();
        if (ids.Length == 0) return ids;

        var found = await dbContext.Subjects.CountAsync(
            x => ids.Contains(x.Id) && x.SchoolClassId == classId && x.IsActive,
            cancellationToken);
        return found == ids.Length ? ids : null;
    }

    private async Task<IReadOnlyCollection<Guid>?> ActiveTeacherIdsAsync(
        Guid classId,
        IReadOnlyCollection<Guid>? requested,
        CancellationToken cancellationToken)
    {
        var ids = (requested ?? []).Distinct().ToArray();
        if (ids.Length == 0) return ids;

        var found = await dbContext.Teachers.CountAsync(
            x => ids.Contains(x.Id) && x.SchoolClassId == classId && x.IsActive,
            cancellationToken);
        return found == ids.Length ? ids : null;
    }

    private async Task ReplaceSubjectLinksAsync(Guid subjectId, IReadOnlyCollection<Guid> teacherIds, CancellationToken cancellationToken)
    {
        var existing = await dbContext.SubjectTeachers.Where(x => x.SubjectId == subjectId).ToListAsync(cancellationToken);
        dbContext.SubjectTeachers.RemoveRange(existing.Where(x => !teacherIds.Contains(x.TeacherId)));
        dbContext.SubjectTeachers.AddRange(teacherIds
            .Where(teacherId => existing.All(x => x.TeacherId != teacherId))
            .Select(teacherId => new SubjectTeacher { SubjectId = subjectId, TeacherId = teacherId }));
    }

    private async Task ReplaceTeacherLinksAsync(Guid teacherId, IReadOnlyCollection<Guid> subjectIds, CancellationToken cancellationToken)
    {
        var existing = await dbContext.SubjectTeachers.Where(x => x.TeacherId == teacherId).ToListAsync(cancellationToken);
        dbContext.SubjectTeachers.RemoveRange(existing.Where(x => !subjectIds.Contains(x.SubjectId)));
        dbContext.SubjectTeachers.AddRange(subjectIds
            .Where(subjectId => existing.All(x => x.SubjectId != subjectId))
            .Select(subjectId => new SubjectTeacher { SubjectId = subjectId, TeacherId = teacherId }));
    }

    private TeacherResponse ToResponse(Teacher teacher, IReadOnlyCollection<Guid> subjectIds) => new(
        teacher.Id,
        protector.Unprotect(teacher.EncryptedDisplayName, ProfessorDisplayPurpose),
        UnprotectOptional(teacher.EncryptedInformation, ProfessorInfoPurpose),
        teacher.IsActive,
        subjectIds);

    private TeacherResponse? TryToResponse(Teacher teacher)
    {
        try
        {
            return ToResponse(teacher, teacher.SubjectLinks.Select(x => x.SubjectId).ToArray());
        }
        catch (CryptographicException)
        {
            // Local development databases can contain old encrypted demo rows after a key
            // change. We skip unreadable rows instead of breaking the whole resource screen.
            return null;
        }
    }

    // « M. Dupont » et « Mme Durand » sont triés sur le nom, pas sur la civilité.
    private static string SortableName(string displayName)
    {
        foreach (var prefix in new[] { "M. ", "Mme ", "Mlle " })
        {
            if (displayName.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) return displayName[prefix.Length..];
        }

        return displayName;
    }

    private string? ProtectOptional(string? value, string purpose) =>
        string.IsNullOrWhiteSpace(value) ? null : protector.Protect(value.Trim(), purpose);

    private string? UnprotectOptional(string? value, string purpose) =>
        string.IsNullOrWhiteSpace(value) ? null : protector.Unprotect(value, purpose);
}
