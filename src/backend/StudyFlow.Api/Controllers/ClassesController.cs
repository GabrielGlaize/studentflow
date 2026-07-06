using System.Security.Claims;
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

[ApiController]
[Authorize]
[Route("api/v1/classes")]
public sealed class SchoolClassesController(
    UserManager<ApplicationUser> userManager,
    StudyFlowDbContext dbContext,
    IClassCodeService classCodeService,
    IAuthTokenService tokenService) : ControllerBase
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

        var isDelegate = await userManager.IsInRoleAsync(user, nameof(UserRole.Delegue));
        return Ok(ToCurrentClassResponse(schoolClass, isDelegate));
    }

    [HttpPost("join")]
    public async Task<ActionResult<MembershipRequestResponse>> Join(
        JoinClassRequest request,
        CancellationToken cancellationToken)
    {
        var userId = CurrentUserId();
        var user = await userManager.FindByIdAsync(userId.ToString());
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
        if (string.IsNullOrWhiteSpace(schoolYear)) return BadRequestProblem("L'annee scolaire est obligatoire.");

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

        if (!await userManager.IsInRoleAsync(user, nameof(UserRole.Eleve)))
        {
            var studentRoleResult = await userManager.AddToRoleAsync(user, nameof(UserRole.Eleve));
            if (!studentRoleResult.Succeeded) return IdentityValidationProblem(studentRoleResult);
        }

        if (!await userManager.IsInRoleAsync(user, nameof(UserRole.Delegue)))
        {
            var delegateRoleResult = await userManager.AddToRoleAsync(user, nameof(UserRole.Delegue));
            if (!delegateRoleResult.Succeeded) return IdentityValidationProblem(delegateRoleResult);
        }

        await userManager.UpdateSecurityStampAsync(user);

        await transaction.CommitAsync(cancellationToken);

        var roles = await userManager.GetRolesAsync(user);
        var response = new AuthResponse(
            await tokenService.IssueAsync(user.Id, cancellationToken),
            new UserSummary(
                user.Id,
                user.Email ?? string.Empty,
                user.FirstName,
                user.LastName,
                user.SchoolClassId,
                roles.ToArray()),
            code.Plaintext);

        return Ok(response);
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
        if (string.IsNullOrWhiteSpace(schoolYear)) return BadRequestProblem("L'annee scolaire est obligatoire.");

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

        var members = await dbContext.Users
            .AsNoTracking()
            .Where(x => x.SchoolClassId == user.SchoolClassId)
            .OrderBy(x => x.LastName)
            .ThenBy(x => x.FirstName)
            .ToListAsync(cancellationToken);

        var responses = new List<ClassMemberResponse>(members.Count);
        foreach (var member in members)
        {
            responses.Add(new ClassMemberResponse(
                member.Id,
                member.FirstName,
                member.LastName,
                member.Email ?? string.Empty,
                await userManager.IsInRoleAsync(member, nameof(UserRole.Delegue))));
        }

        return Ok(responses);
    }

    [Authorize(Roles = nameof(UserRole.Delegue))]
    [HttpPost("current/members/{memberId:guid}/make-delegate")]
    public async Task<IActionResult> MakeDelegate(Guid memberId, CancellationToken cancellationToken)
    {
        var currentUser = await CurrentUserAsync();
        if (currentUser?.SchoolClassId is null) return Forbid();

        var member = await userManager.FindByIdAsync(memberId.ToString());
        if (member?.SchoolClassId != currentUser.SchoolClassId) return NotFound();

        if (!await userManager.IsInRoleAsync(member, nameof(UserRole.Eleve)))
        {
            await userManager.AddToRoleAsync(member, nameof(UserRole.Eleve));
        }

        if (!await userManager.IsInRoleAsync(member, nameof(UserRole.Delegue)))
        {
            var result = await userManager.AddToRoleAsync(member, nameof(UserRole.Delegue));
            if (!result.Succeeded) return IdentityValidationProblem(result);
        }

        await userManager.UpdateSecurityStampAsync(member);
        return NoContent();
    }

    [Authorize(Roles = nameof(UserRole.Delegue))]
    [HttpDelete("current/members/{memberId:guid}")]
    public async Task<IActionResult> RemoveMember(Guid memberId, CancellationToken cancellationToken)
    {
        var currentUser = await CurrentUserAsync();
        if (currentUser?.SchoolClassId is null) return Forbid();
        if (memberId == currentUser.Id) return ConflictProblem("Un delegue ne peut pas se retirer lui-meme de la classe.");

        var member = await userManager.FindByIdAsync(memberId.ToString());
        if (member?.SchoolClassId != currentUser.SchoolClassId) return NotFound();

        member.SchoolClassId = null;
        member.UpdatedAt = DateTimeOffset.UtcNow;

        if (await userManager.IsInRoleAsync(member, nameof(UserRole.Delegue)))
        {
            var delegateResult = await userManager.RemoveFromRoleAsync(member, nameof(UserRole.Delegue));
            if (!delegateResult.Succeeded) return IdentityValidationProblem(delegateResult);
        }

        if (await userManager.IsInRoleAsync(member, nameof(UserRole.Eleve)))
        {
            var studentResult = await userManager.RemoveFromRoleAsync(member, nameof(UserRole.Eleve));
            if (!studentResult.Succeeded) return IdentityValidationProblem(studentResult);
        }

        await userManager.UpdateAsync(member);
        await userManager.UpdateSecurityStampAsync(member);
        return NoContent();
    }

    [Authorize(Roles = nameof(UserRole.Delegue))]
    [HttpPost("current/delegate-role/leave")]
    public async Task<IActionResult> LeaveDelegateRole(CancellationToken cancellationToken)
    {
        var currentUser = await CurrentUserAsync();
        if (currentUser?.SchoolClassId is null) return Forbid();

        var delegateRoleId = await dbContext.Roles
            .Where(role => role.Name == nameof(UserRole.Delegue))
            .Select(role => role.Id)
            .SingleAsync(cancellationToken);

        var delegateIds = await dbContext.UserRoles
            .Where(x => x.RoleId == delegateRoleId)
            .Select(x => x.UserId)
            .ToListAsync(cancellationToken);

        var delegateCountInClass = await dbContext.Users
            .CountAsync(x => x.SchoolClassId == currentUser.SchoolClassId && delegateIds.Contains(x.Id), cancellationToken);

        if (delegateCountInClass <= 1)
        {
            return ConflictProblem("Nommez un autre delegue avant de quitter ce role.");
        }

        var result = await userManager.RemoveFromRoleAsync(currentUser, nameof(UserRole.Delegue));
        if (!result.Succeeded) return IdentityValidationProblem(result);

        await userManager.UpdateSecurityStampAsync(currentUser);
        return NoContent();
    }

    [HttpPost("current/leave")]
    public async Task<ActionResult<AuthResponse>> LeaveClass(CancellationToken cancellationToken)
    {
        var currentUser = await CurrentUserAsync();
        if (currentUser?.SchoolClassId is null) return Forbid();

        var classId = currentUser.SchoolClassId.Value;
        var membersCount = await dbContext.Users
            .CountAsync(x => x.SchoolClassId == classId && x.IsActive, cancellationToken);

        if (await userManager.IsInRoleAsync(currentUser, nameof(UserRole.Delegue)) && membersCount > 1)
        {
            var delegateRoleId = await dbContext.Roles
                .Where(role => role.Name == nameof(UserRole.Delegue))
                .Select(role => role.Id)
                .SingleAsync(cancellationToken);

            var otherDelegateExists = await dbContext.UserRoles
                .Join(
                    dbContext.Users,
                    userRole => userRole.UserId,
                    user => user.Id,
                    (userRole, user) => new { userRole, user })
                .AnyAsync(
                    x => x.userRole.RoleId == delegateRoleId
                        && x.user.SchoolClassId == classId
                        && x.user.Id != currentUser.Id
                        && x.user.IsActive,
                    cancellationToken);

            if (!otherDelegateExists)
            {
                return ConflictProblem("Nommez un autre delegue avant de quitter la classe.");
            }
        }

        currentUser.SchoolClassId = null;
        currentUser.UpdatedAt = DateTimeOffset.UtcNow;

        if (await userManager.IsInRoleAsync(currentUser, nameof(UserRole.Delegue)))
        {
            var delegateResult = await userManager.RemoveFromRoleAsync(currentUser, nameof(UserRole.Delegue));
            if (!delegateResult.Succeeded) return IdentityValidationProblem(delegateResult);
        }

        if (await userManager.IsInRoleAsync(currentUser, nameof(UserRole.Eleve)))
        {
            var studentResult = await userManager.RemoveFromRoleAsync(currentUser, nameof(UserRole.Eleve));
            if (!studentResult.Succeeded) return IdentityValidationProblem(studentResult);
        }

        await userManager.UpdateAsync(currentUser);
        await userManager.UpdateSecurityStampAsync(currentUser);

        var roles = await userManager.GetRolesAsync(currentUser);
        return Ok(new AuthResponse(
            await tokenService.IssueAsync(currentUser.Id, cancellationToken),
            new UserSummary(
                currentUser.Id,
                currentUser.Email ?? string.Empty,
                currentUser.FirstName,
                currentUser.LastName,
                currentUser.SchoolClassId,
                roles.ToArray())));
    }

    [HttpGet("current-request")]
    public async Task<ActionResult<MembershipRequestResponse>> CurrentRequest(CancellationToken cancellationToken)
    {
        var membership = await dbContext.ClassMembershipRequests
            .AsNoTracking()
            .Where(x => x.UserId == CurrentUserId())
            .OrderByDescending(x => x.RequestedAt)
            .FirstOrDefaultAsync(cancellationToken);

        return membership is null
            ? NotFound()
            : Ok(new MembershipRequestResponse(membership.Id, membership.Status.ToString(), membership.RequestedAt));
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

    private async Task<ApplicationUser?> CurrentUserAsync() =>
        await userManager.FindByIdAsync(CurrentUserId().ToString());

    private Guid CurrentUserId() => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    private ObjectResult BadRequestProblem(string title) =>
        BadRequest(new ProblemDetails { Title = title, Status = StatusCodes.Status400BadRequest });

    private ObjectResult ConflictProblem(string title) =>
        Conflict(new ProblemDetails { Title = title, Status = StatusCodes.Status409Conflict });

    private ActionResult IdentityValidationProblem(IdentityResult result) =>
        ValidationProblem(new ValidationProblemDetails(result.Errors
            .GroupBy(x => x.Code)
            .ToDictionary(x => x.Key, x => x.Select(error => error.Description).ToArray())));
}
