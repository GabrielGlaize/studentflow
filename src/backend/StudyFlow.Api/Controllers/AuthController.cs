using System.Security.Claims;
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
[Route("api/v1/auth")]
public sealed class AuthController(
    UserManager<ApplicationUser> userManager,
    StudyFlowDbContext dbContext,
    IAuthTokenService tokenService,
    IPasswordResetService passwordResetService,
    IClassCodeService classCodeService) : ControllerBase
{
    [EnableRateLimiting("auth-sensitive")]
    [HttpPost("register")]
    public async Task<ActionResult<AuthResponse>> Register(RegisterRequest request, CancellationToken cancellationToken)
    {
        var user = NewUser(request.Email, request.FirstName, request.LastName);
        var result = await userManager.CreateAsync(user, request.Password);
        if (!result.Succeeded) return IdentityErrors(result);

        return Ok(await CreateResponseAsync(user, cancellationToken));
    }

    [EnableRateLimiting("auth-sensitive")]
    [HttpPost("register-and-create-class")]
    public async Task<ActionResult<AuthResponse>> RegisterAndCreateClass(
        RegisterAndCreateClassRequest request,
        CancellationToken cancellationToken)
    {
        await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);
        var user = NewUser(request.Email, request.FirstName, request.LastName);
        var result = await userManager.CreateAsync(user, request.Password);
        if (!result.Succeeded) return IdentityErrors(result);

        var code = classCodeService.Generate();
        var schoolClass = new SchoolClass
        {
            Name = request.SchoolClassName.Trim(),
            SchoolYear = request.SchoolYear.Trim(),
            AccessCodeHash = code.Hash,
            EncryptedAccessCode = code.Ciphertext,
            AccessCodeUpdatedAt = DateTimeOffset.UtcNow,
            CreatedById = user.Id
        };
        dbContext.SchoolClasses.Add(schoolClass);
        user.SchoolClassId = schoolClass.Id;
        user.UpdatedAt = DateTimeOffset.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);

        result = await userManager.AddToRolesAsync(user, [nameof(UserRole.Eleve), nameof(UserRole.Delegue)]);
        if (!result.Succeeded) return IdentityErrors(result);

        await transaction.CommitAsync(cancellationToken);
        return Ok(await CreateResponseAsync(user, cancellationToken, code.Plaintext));
    }

    [EnableRateLimiting("auth-sensitive")]
    [HttpPost("login")]
    public async Task<ActionResult<AuthResponse>> Login(LoginRequest request, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByEmailAsync(request.Email.Trim());
        if (user is null || !user.IsActive || !await userManager.CheckPasswordAsync(user, request.Password))
        {
            return Unauthorized(new ProblemDetails { Title = "Identifiants invalides", Status = StatusCodes.Status401Unauthorized });
        }

        return Ok(await CreateResponseAsync(user, cancellationToken));
    }

    [EnableRateLimiting("auth-sensitive")]
    [HttpPost("refresh")]
    public async Task<ActionResult<AuthTokenPair>> Refresh(RefreshRequest request, CancellationToken cancellationToken)
    {
        var pair = await tokenService.RotateAsync(request.RefreshToken, cancellationToken);
        return pair is null ? Unauthorized() : Ok(pair);
    }

    [Authorize]
    [HttpPost("logout")]
    public async Task<IActionResult> Logout(LogoutRequest request, CancellationToken cancellationToken)
    {
        var userId = CurrentUserId();
        await tokenService.RevokeAsync(userId, request.RefreshToken, cancellationToken);
        return NoContent();
    }

    [Authorize]
    [HttpDelete("me")]
    public async Task<IActionResult> DeleteAccount(CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(CurrentUserId().ToString());
        if (user is null) return Unauthorized();

        user.IsActive = false;
        user.SchoolClassId = null;
        user.UpdatedAt = DateTimeOffset.UtcNow;

        var activeRefreshTokens = await dbContext.RefreshTokens
            .Where(x => x.UserId == user.Id && x.RevokedAt == null && x.ExpiresAt > DateTimeOffset.UtcNow)
            .ToListAsync(cancellationToken);
        foreach (var refreshToken in activeRefreshTokens)
        {
            refreshToken.RevokedAt = DateTimeOffset.UtcNow;
        }

        var activeResetTokens = await dbContext.PasswordResetTokens
            .Where(x => x.UserId == user.Id && x.UsedAt == null && x.RevokedAt == null)
            .ToListAsync(cancellationToken);
        foreach (var resetToken in activeResetTokens)
        {
            resetToken.RevokedAt = DateTimeOffset.UtcNow;
        }

        await userManager.UpdateSecurityStampAsync(user);
        await userManager.UpdateAsync(user);
        await dbContext.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    [EnableRateLimiting("auth-sensitive")]
    [HttpPost("forgot-password")]
    public async Task<ActionResult<ForgotPasswordResponse>> ForgotPassword(
        ForgotPasswordRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Email))
        {
            return BadRequest(new ProblemDetails
            {
                Title = "L'adresse e-mail est obligatoire.",
                Status = StatusCodes.Status400BadRequest
            });
        }

        var result = await passwordResetService.RequestResetAsync(request.Email, cancellationToken);

        return Ok(new ForgotPasswordResponse(
            "Si un compte existe avec cet e-mail, un lien de réinitialisation a été préparé.",
            result.DevelopmentToken,
            result.ExpiresAt));
    }

    [EnableRateLimiting("auth-sensitive")]
    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword(
        ResetPasswordRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Email)
            || string.IsNullOrWhiteSpace(request.Token)
            || string.IsNullOrWhiteSpace(request.NewPassword))
        {
            return BadRequest(new ProblemDetails
            {
                Title = "E-mail, code et nouveau mot de passe sont obligatoires.",
                Status = StatusCodes.Status400BadRequest
            });
        }

        var succeeded = await passwordResetService.ResetPasswordAsync(
            request.Email,
            request.Token,
            request.NewPassword,
            cancellationToken);

        return succeeded
            ? NoContent()
            : BadRequest(new ProblemDetails
            {
                Title = "Le code de réinitialisation est invalide ou expiré.",
                Status = StatusCodes.Status400BadRequest
            });
    }

    [Authorize]
    [HttpGet("me")]
    public async Task<ActionResult<UserSummary>> Me()
    {
        var user = await userManager.FindByIdAsync(CurrentUserId().ToString());
        if (user is null) return Unauthorized();
        return Ok(await SummaryAsync(user));
    }

    private async Task<AuthResponse> CreateResponseAsync(ApplicationUser user, CancellationToken cancellationToken, string? classCode = null) =>
        new(await tokenService.IssueAsync(user.Id, cancellationToken), await SummaryAsync(user), classCode);

    private async Task<UserSummary> SummaryAsync(ApplicationUser user) =>
        new(user.Id, user.Email ?? string.Empty, user.FirstName, user.LastName, user.SchoolClassId,
            (await userManager.GetRolesAsync(user)).ToArray());

    private Guid CurrentUserId() => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    private static ApplicationUser NewUser(string email, string firstName, string lastName) => new()
    {
        Id = Guid.NewGuid(),
        UserName = email.Trim(),
        Email = email.Trim(),
        FirstName = firstName.Trim(),
        LastName = lastName.Trim()
    };

    private ActionResult IdentityErrors(IdentityResult result) => ValidationProblem(new ValidationProblemDetails(
        result.Errors.GroupBy(x => x.Code).ToDictionary(x => x.Key, x => x.Select(error => error.Description).ToArray())));
}
