using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using StudyFlow.Api.Contracts;
using StudyFlow.Application.Accounts;
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
    IClassCodeService classCodeService,
    IAccountDeletionService accountDeletionService) : StudyFlowControllerBase(userManager)
{
    [EnableRateLimiting(RateLimiting.Credentials)]
    [HttpPost("register")]
    public async Task<ActionResult<AuthResponse>> Register(RegisterRequest request, CancellationToken cancellationToken)
    {
        var namesProblem = ValidateNames(request.FirstName, request.LastName);
        if (namesProblem is not null) return namesProblem;

        var user = NewUser(request.Email, request.FirstName, request.LastName);
        var result = await UserManager.CreateAsync(user, request.Password);
        if (!result.Succeeded) return IdentityValidationProblem(result);

        return Ok(await CreateResponseAsync(user, cancellationToken));
    }

    [EnableRateLimiting(RateLimiting.Credentials)]
    [HttpPost("register-and-create-class")]
    public async Task<ActionResult<AuthResponse>> RegisterAndCreateClass(
        RegisterAndCreateClassRequest request,
        CancellationToken cancellationToken)
    {
        var namesProblem = ValidateNames(request.FirstName, request.LastName);
        if (namesProblem is not null) return namesProblem;

        var className = request.SchoolClassName.Trim();
        var schoolYear = request.SchoolYear.Trim();
        if (string.IsNullOrWhiteSpace(className)) return BadRequestProblem("Le nom de la classe est obligatoire.");
        if (!InputRules.IsSchoolYear(schoolYear)) return BadRequestProblem(InputRules.SchoolYearMessage);
        if (await dbContext.SchoolClasses.AnyAsync(x => x.Name == className, cancellationToken))
        {
            return ConflictProblem("Ce nom de classe est deja utilise.");
        }

        await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);
        var user = NewUser(request.Email, request.FirstName, request.LastName);
        var result = await UserManager.CreateAsync(user, request.Password);
        if (!result.Succeeded) return IdentityValidationProblem(result);

        var code = classCodeService.Generate();
        var schoolClass = new SchoolClass
        {
            Name = className,
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

        result = await UserManager.AddToRolesAsync(user, [nameof(UserRole.Eleve), nameof(UserRole.Delegue)]);
        if (!result.Succeeded) return IdentityValidationProblem(result);

        await transaction.CommitAsync(cancellationToken);
        return Ok(await CreateResponseAsync(user, cancellationToken, code.Plaintext));
    }

    [EnableRateLimiting(RateLimiting.Credentials)]
    [HttpPost("login")]
    public async Task<ActionResult<AuthResponse>> Login(LoginRequest request, CancellationToken cancellationToken)
    {
        var user = await UserManager.FindByEmailAsync(request.Email.Trim());
        if (user is null || !user.IsActive) return InvalidCredentials();

        // Même réponse pour un compte verrouillé : elle ne doit pas révéler qu'un compte existe.
        if (await UserManager.IsLockedOutAsync(user)) return InvalidCredentials();

        if (!await UserManager.CheckPasswordAsync(user, request.Password))
        {
            await UserManager.AccessFailedAsync(user);
            return InvalidCredentials();
        }

        await UserManager.ResetAccessFailedCountAsync(user);
        return Ok(await CreateResponseAsync(user, cancellationToken));
    }

    [EnableRateLimiting(RateLimiting.Refresh)]
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
        await tokenService.RevokeAsync(CurrentUserId, request.RefreshToken, cancellationToken);
        return NoContent();
    }

    [Authorize]
    [HttpDelete("me")]
    public async Task<IActionResult> DeleteAccount(CancellationToken cancellationToken)
    {
        var result = await accountDeletionService.DeleteAsync(CurrentUserId, cancellationToken);
        return result switch
        {
            AccountDeletionResult.Deleted => NoContent(),
            AccountDeletionResult.LastDelegate => ConflictProblem(
                "Nommez un autre delegue avant de supprimer votre compte."),
            _ => Unauthorized()
        };
    }

    [EnableRateLimiting(RateLimiting.Credentials)]
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
            "Si un compte existe avec cette adresse, un code vient d'y être envoyé (pense à regarder les spams). Il est valable 30 minutes.",
            result.DevelopmentToken,
            result.ExpiresAt));
    }

    [EnableRateLimiting(RateLimiting.Credentials)]
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
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();
        return Ok(await SummaryAsync(user));
    }

    private async Task<AuthResponse> CreateResponseAsync(ApplicationUser user, CancellationToken cancellationToken, string? classCode = null) =>
        new(await tokenService.IssueAsync(user.Id, cancellationToken), await SummaryAsync(user), classCode);

    private async Task<UserSummary> SummaryAsync(ApplicationUser user) =>
        new(user.Id, user.Email ?? string.Empty, user.FirstName, user.LastName, user.SchoolClassId,
            (await UserManager.GetRolesAsync(user)).ToArray());

    private ObjectResult InvalidCredentials() => Unauthorized(new ProblemDetails
    {
        Title = "Identifiants invalides",
        Detail = "E-mail ou mot de passe incorrect. Après 5 essais ratés, le compte est bloqué 15 minutes.",
        Status = StatusCodes.Status401Unauthorized
    });

    private ObjectResult? ValidateNames(string firstName, string lastName)
    {
        if (string.IsNullOrWhiteSpace(firstName)) return BadRequestProblem("Le prenom est obligatoire.");
        if (string.IsNullOrWhiteSpace(lastName)) return BadRequestProblem("Le nom est obligatoire.");
        return null;
    }

    private static ApplicationUser NewUser(string email, string firstName, string lastName) => new()
    {
        Id = Guid.NewGuid(),
        UserName = email.Trim(),
        Email = email.Trim(),
        FirstName = firstName.Trim(),
        LastName = lastName.Trim()
    };
}
