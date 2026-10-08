using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using StudyFlow.Api.Contracts;
using StudyFlow.Application.Security;
using StudyFlow.Domain.School;
using StudyFlow.Domain.Users;
using StudyFlow.Infrastructure.Identity;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/classes")]
public sealed class SchoolClassesController(
    UserManager<ApplicationUser> userManager,
    StudyFlowDbContext dbContext,
    IClassCodeService classCodeService,
    IAuthTokenService tokenService) : StudyFlowControllerBase(userManager)
{
    [HttpGet("current")]
    public async Task<ActionResult<CurrentClassResponse>> Current(CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return NotFound();

        var schoolClass = await dbContext.SchoolClasses
            .AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == user.SchoolClassId && x.IsActive, cancellationToken);
        if (schoolClass is null) return NotFound();

        var isDelegate = await UserManager.IsInRoleAsync(user, nameof(UserRole.Delegue));
        return Ok(ToCurrentClassResponse(schoolClass, isDelegate));
    }

    // Limite par utilisateur : un code de classe ne doit pas pouvoir être deviné par essais successifs.
    [EnableRateLimiting(RateLimiting.ClassJoin)]
    [HttpPost("join")]
    public async Task<ActionResult<MembershipRequestResponse>> Join(
        JoinClassRequest request,
        CancellationToken cancellationToken)
    {
        var userId = CurrentUserId;
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();
        if (user.SchoolClassId is not null) return ConflictProblem("Vous appartenez deja a une classe.");

        var pending = await dbContext.ClassMembershipRequests
            .AnyAsync(x => x.UserId == userId && x.Status == ClassMembershipRequestStatus.Pending, cancellationToken);
        if (pending) return ConflictProblem("Une demande est deja en attente.");

        var codeHash = classCodeService.ComputeHash(request.Code);
        var schoolClass = await dbContext.SchoolClasses
            .SingleOrDefaultAsync(x => x.AccessCodeHash == codeHash && x.IsActive, cancellationToken);
        if (schoolClass is null) return NotFound(new ProblemDetails { Title = "Code de classe invalide" });

        var membership = new ClassMembershipRequest { SchoolClassId = schoolClass.Id, UserId = userId };
        dbContext.ClassMembershipRequests.Add(membership);
        await dbContext.SaveChangesAsync(cancellationToken);

        return CreatedAtAction(nameof(CurrentRequest), new MembershipRequestResponse(
            membership.Id, membership.Status.ToString(), membership.RequestedAt));
    }

    [HttpPost]
    public async Task<ActionResult<AuthResponse>> Create(
        CreateClassRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();
        if (user.SchoolClassId is not null) return ConflictProblem("Vous appartenez deja a une classe.");

        var name = request.SchoolClassName.Trim();
        var schoolYear = request.SchoolYear.Trim();
        if (string.IsNullOrWhiteSpace(name)) return BadRequestProblem("Le nom de la classe est obligatoire.");
        if (!InputRules.IsSchoolYear(schoolYear)) return BadRequestProblem(InputRules.SchoolYearMessage);

        var nameAlreadyUsed = await dbContext.SchoolClasses.AnyAsync(
            x => x.Name == name,
            cancellationToken);
        if (nameAlreadyUsed) return ConflictProblem("Ce nom de classe est deja utilise.");

        await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);
        var code = classCodeService.Generate();
        var schoolClass = new SchoolClass
        {
            Name = name,
            SchoolYear = schoolYear,
            AccessCodeHash = code.Hash,
            EncryptedAccessCode = code.Ciphertext,
            AccessCodeUpdatedAt = DateTimeOffset.UtcNow,
            CreatedById = user.Id
        };

        dbContext.SchoolClasses.Add(schoolClass);
        user.SchoolClassId = schoolClass.Id;
        user.UpdatedAt = DateTimeOffset.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);

        if (!await UserManager.IsInRoleAsync(user, nameof(UserRole.Eleve)))
        {
            var studentRoleResult = await UserManager.AddToRoleAsync(user, nameof(UserRole.Eleve));
            if (!studentRoleResult.Succeeded) return IdentityValidationProblem(studentRoleResult);
        }

        if (!await UserManager.IsInRoleAsync(user, nameof(UserRole.Delegue)))
        {
            var delegateRoleResult = await UserManager.AddToRoleAsync(user, nameof(UserRole.Delegue));
            if (!delegateRoleResult.Succeeded) return IdentityValidationProblem(delegateRoleResult);
        }

        await UserManager.UpdateSecurityStampAsync(user);

        await transaction.CommitAsync(cancellationToken);

        return Ok(await NewSessionAsync(user, cancellationToken, code.Plaintext));
    }

    [Authorize(Roles = nameof(UserRole.Delegue))]
    [HttpPut("current")]
    public async Task<ActionResult<CurrentClassResponse>> UpdateCurrent(
        UpdateClassRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var schoolClass = await dbContext.SchoolClasses
            .SingleOrDefaultAsync(x => x.Id == user.SchoolClassId && x.IsActive, cancellationToken);
        if (schoolClass is null) return NotFound();

        var name = request.Name.Trim();
        var schoolYear = request.SchoolYear.Trim();
        if (string.IsNullOrWhiteSpace(name)) return BadRequestProblem("Le nom de la classe est obligatoire.");
        if (!InputRules.IsSchoolYear(schoolYear)) return BadRequestProblem(InputRules.SchoolYearMessage);

        var nameAlreadyUsed = await dbContext.SchoolClasses.AnyAsync(
            x => x.Id != schoolClass.Id && x.Name == name,
            cancellationToken);
        if (nameAlreadyUsed) return ConflictProblem("Ce nom de classe est deja utilise.");

        schoolClass.Name = name;
        schoolClass.SchoolYear = schoolYear;
        schoolClass.UpdatedAt = DateTimeOffset.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);

        return Ok(ToCurrentClassResponse(schoolClass, isDelegate: true));
    }

    [Authorize(Roles = nameof(UserRole.Delegue))]
    [HttpGet("current/access-code")]
    public async Task<ActionResult<ClassAccessCodeResponse>> AccessCode(CancellationToken cancellationToken)
    {
        var schoolClass = await CurrentDelegateClassAsync(cancellationToken);
        if (schoolClass is null) return Forbid();

        return Ok(new ClassAccessCodeResponse(
            classCodeService.Reveal(schoolClass.EncryptedAccessCode),
            schoolClass.AccessCodeUpdatedAt));
    }

    [Authorize(Roles = nameof(UserRole.Delegue))]
    [HttpPost("current/access-code/regenerate")]
    public async Task<ActionResult<ClassAccessCodeResponse>> RegenerateAccessCode(CancellationToken cancellationToken)
    {
        var schoolClass = await CurrentDelegateClassAsync(cancellationToken);
        if (schoolClass is null) return Forbid();

        // Regenerer le code invalide l'ancien code partage. C'est utile si le code a trop circule.
        var code = classCodeService.Generate();
        schoolClass.AccessCodeHash = code.Hash;
        schoolClass.EncryptedAccessCode = code.Ciphertext;
        schoolClass.AccessCodeUpdatedAt = DateTimeOffset.UtcNow;
        schoolClass.UpdatedAt = DateTimeOffset.UtcNow;

        await dbContext.SaveChangesAsync(cancellationToken);
        return Ok(new ClassAccessCodeResponse(code.Plaintext, schoolClass.AccessCodeUpdatedAt));
    }

    [HttpGet("current/members")]
    public async Task<ActionResult<IReadOnlyCollection<ClassMemberResponse>>> Members(CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var classId = user.SchoolClassId.Value;
        var delegateIds = await dbContext.ActiveDelegatesOfClass(classId)
            .Select(x => x.Id)
            .ToListAsync(cancellationToken);

        // Minimisation des données : seuls les délégués, qui gèrent la classe, voient les e-mails.
        var showEmails = delegateIds.Contains(user.Id);

        var members = await dbContext.Users
            .AsNoTracking()
            .Where(x => x.SchoolClassId == classId && x.IsActive)
            .OrderBy(x => x.LastName)
            .ThenBy(x => x.FirstName)
            .Select(x => new { x.Id, x.FirstName, x.LastName, x.Email })
            .ToListAsync(cancellationToken);

        return Ok(members.Select(member => new ClassMemberResponse(
            member.Id,
            member.FirstName,
            member.LastName,
            showEmails ? member.Email ?? string.Empty : null,
            delegateIds.Contains(member.Id))).ToArray());
    }

    [Authorize(Roles = nameof(UserRole.Delegue))]
    [HttpPost("current/members/{memberId:guid}/make-delegate")]
    public async Task<IActionResult> MakeDelegate(Guid memberId, CancellationToken cancellationToken)
    {
        var currentUser = await CurrentUserAsync();
        if (currentUser?.SchoolClassId is null) return Forbid();

        var member = await UserManager.FindByIdAsync(memberId.ToString());
        if (member?.SchoolClassId != currentUser.SchoolClassId) return NotFound();

        if (!await UserManager.IsInRoleAsync(member, nameof(UserRole.Eleve)))
        {
            await UserManager.AddToRoleAsync(member, nameof(UserRole.Eleve));
        }

        if (!await UserManager.IsInRoleAsync(member, nameof(UserRole.Delegue)))
        {
            var result = await UserManager.AddToRoleAsync(member, nameof(UserRole.Delegue));
            if (!result.Succeeded) return IdentityValidationProblem(result);
        }

        await UserManager.UpdateSecurityStampAsync(member);
        return NoContent();
    }

    [Authorize(Roles = nameof(UserRole.Delegue))]
    [HttpDelete("current/members/{memberId:guid}")]
    public async Task<IActionResult> RemoveMember(Guid memberId, CancellationToken cancellationToken)
    {
        var currentUser = await CurrentUserAsync();
        if (currentUser?.SchoolClassId is null) return Forbid();
        if (memberId == currentUser.Id) return ConflictProblem("Un delegue ne peut pas se retirer lui-meme de la classe.");

        var member = await UserManager.FindByIdAsync(memberId.ToString());
        if (member?.SchoolClassId != currentUser.SchoolClassId) return NotFound();

        member.SchoolClassId = null;
        member.UpdatedAt = DateTimeOffset.UtcNow;

        var rolesProblem = await RemoveClassRolesAsync(member);
        if (rolesProblem is not null) return rolesProblem;

        await UserManager.UpdateAsync(member);
        await UserManager.UpdateSecurityStampAsync(member);
        return NoContent();
    }

    [Authorize(Roles = nameof(UserRole.Delegue))]
    [HttpPost("current/delegate-role/leave")]
    public async Task<IActionResult> LeaveDelegateRole(CancellationToken cancellationToken)
    {
        var currentUser = await CurrentUserAsync();
        if (currentUser?.SchoolClassId is null) return Forbid();

        var delegateCountInClass = await dbContext.ActiveDelegatesOfClass(currentUser.SchoolClassId.Value)
            .CountAsync(cancellationToken);
        if (delegateCountInClass <= 1)
        {
            return ConflictProblem("Nommez un autre delegue avant de quitter ce role.");
        }

        var result = await UserManager.RemoveFromRoleAsync(currentUser, nameof(UserRole.Delegue));
        if (!result.Succeeded) return IdentityValidationProblem(result);

        await UserManager.UpdateSecurityStampAsync(currentUser);
        return NoContent();
    }

    [HttpPost("current/leave")]
    public async Task<ActionResult<AuthResponse>> LeaveClass(CancellationToken cancellationToken)
    {
        var currentUser = await CurrentUserAsync();
        if (currentUser?.SchoolClassId is null) return Forbid();

        var classId = currentUser.SchoolClassId.Value;
        var otherMembersCount = await dbContext.Users
            .CountAsync(x => x.SchoolClassId == classId && x.IsActive && x.Id != currentUser.Id, cancellationToken);

        if (otherMembersCount > 0 && await UserManager.IsInRoleAsync(currentUser, nameof(UserRole.Delegue)))
        {
            var otherDelegateExists = await dbContext.ActiveDelegatesOfClass(classId)
                .AnyAsync(x => x.Id != currentUser.Id, cancellationToken);

            if (!otherDelegateExists)
            {
                return ConflictProblem("Nommez un autre delegue avant de quitter la classe.");
            }
        }

        if (otherMembersCount == 0)
        {
            // Plus personne ne pourrait valider les demandes faites avec le code de cette classe.
            var schoolClass = await dbContext.SchoolClasses.SingleAsync(x => x.Id == classId, cancellationToken);
            schoolClass.IsActive = false;
            schoolClass.UpdatedAt = DateTimeOffset.UtcNow;
        }

        currentUser.SchoolClassId = null;
        currentUser.UpdatedAt = DateTimeOffset.UtcNow;

        var rolesProblem = await RemoveClassRolesAsync(currentUser);
        if (rolesProblem is not null) return rolesProblem;

        await UserManager.UpdateAsync(currentUser);
        await UserManager.UpdateSecurityStampAsync(currentUser);

        return Ok(await NewSessionAsync(currentUser, cancellationToken));
    }

    [HttpGet("current-request")]
    public async Task<ActionResult<MembershipRequestResponse>> CurrentRequest(CancellationToken cancellationToken)
    {
        var membership = await dbContext.ClassMembershipRequests
            .AsNoTracking()
            .Where(x => x.UserId == CurrentUserId)
            .OrderByDescending(x => x.RequestedAt)
            .FirstOrDefaultAsync(cancellationToken);

        return membership is null
            ? NotFound()
            : Ok(new MembershipRequestResponse(membership.Id, membership.Status.ToString(), membership.RequestedAt));
    }

    private async Task<ActionResult?> RemoveClassRolesAsync(ApplicationUser member)
    {
        foreach (var role in new[] { nameof(UserRole.Delegue), nameof(UserRole.Eleve) })
        {
            if (!await UserManager.IsInRoleAsync(member, role)) continue;

            var result = await UserManager.RemoveFromRoleAsync(member, role);
            if (!result.Succeeded) return IdentityValidationProblem(result);
        }

        return null;
    }

    private async Task<AuthResponse> NewSessionAsync(
        ApplicationUser user,
        CancellationToken cancellationToken,
        string? classCode = null)
    {
        var roles = await UserManager.GetRolesAsync(user);
        return new AuthResponse(
            await tokenService.IssueAsync(user.Id, cancellationToken),
            new UserSummary(
                user.Id,
                user.Email ?? string.Empty,
                user.FirstName,
                user.LastName,
                user.SchoolClassId,
                roles.ToArray()),
            classCode);
    }

    private CurrentClassResponse ToCurrentClassResponse(SchoolClass schoolClass, bool isDelegate) => new(
        schoolClass.Id,
        schoolClass.Name,
        schoolClass.SchoolYear,
        isDelegate,
        isDelegate ? classCodeService.Reveal(schoolClass.EncryptedAccessCode) : null,
        schoolClass.AccessCodeUpdatedAt);

    private async Task<SchoolClass?> CurrentDelegateClassAsync(CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return null;

        return await dbContext.SchoolClasses
            .SingleOrDefaultAsync(x => x.Id == user.SchoolClassId && x.IsActive, cancellationToken);
    }
}
