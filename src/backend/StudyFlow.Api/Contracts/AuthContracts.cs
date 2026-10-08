using System.ComponentModel.DataAnnotations;
using StudyFlow.Application.Security;

namespace StudyFlow.Api.Contracts;

public sealed record RegisterRequest(
    [StringLength(320, ErrorMessage = "E-mail : 320 caractères maximum.")] string Email,
    [StringLength(128, ErrorMessage = "Mot de passe : 128 caractères maximum.")] string Password,
    [StringLength(80, ErrorMessage = "Prénom : 80 caractères maximum.")] string FirstName,
    [StringLength(80, ErrorMessage = "Nom : 80 caractères maximum.")] string LastName);
public sealed record RegisterAndCreateClassRequest(
    [StringLength(320, ErrorMessage = "E-mail : 320 caractères maximum.")] string Email,
    [StringLength(128, ErrorMessage = "Mot de passe : 128 caractères maximum.")] string Password,
    [StringLength(80, ErrorMessage = "Prénom : 80 caractères maximum.")] string FirstName,
    [StringLength(80, ErrorMessage = "Nom : 80 caractères maximum.")] string LastName,
    [StringLength(80, ErrorMessage = "Nom de la classe : 80 caractères maximum.")] string SchoolClassName,
    [StringLength(9, ErrorMessage = "L'année scolaire doit être au format 2026-2027.")] string SchoolYear);
public sealed record CreateClassRequest(
    [StringLength(80, ErrorMessage = "Nom de la classe : 80 caractères maximum.")] string SchoolClassName,
    [StringLength(9, ErrorMessage = "L'année scolaire doit être au format 2026-2027.")] string SchoolYear);
public sealed record LoginRequest([StringLength(320, ErrorMessage = "E-mail : 320 caractères maximum.")] string Email, [StringLength(128, ErrorMessage = "Mot de passe : 128 caractères maximum.")] string Password);
public sealed record RefreshRequest([StringLength(200, ErrorMessage = "Jeton : 200 caractères maximum.")] string RefreshToken);
public sealed record LogoutRequest([StringLength(200, ErrorMessage = "Jeton : 200 caractères maximum.")] string RefreshToken);
public sealed record ForgotPasswordRequest([StringLength(320, ErrorMessage = "E-mail : 320 caractères maximum.")] string Email);
public sealed record ForgotPasswordResponse(string Message, string? DevelopmentToken = null, DateTimeOffset? ExpiresAt = null);
public sealed record ResetPasswordRequest(
    [StringLength(320, ErrorMessage = "E-mail : 320 caractères maximum.")] string Email,
    [StringLength(200, ErrorMessage = "Jeton : 200 caractères maximum.")] string Token,
    [StringLength(128, ErrorMessage = "Mot de passe : 128 caractères maximum.")] string NewPassword);
public sealed record AuthResponse(AuthTokenPair Tokens, UserSummary User, string? ClassCode = null);
public sealed record UserSummary(Guid Id, string Email, string FirstName, string LastName, Guid? SchoolClassId, IReadOnlyCollection<string> Roles);

public sealed record JoinClassRequest([StringLength(20, ErrorMessage = "Code de classe : 20 caractères maximum.")] string Code);
public sealed record MembershipRequestResponse(Guid Id, string Status, DateTimeOffset RequestedAt);
public sealed record PendingMembershipResponse(Guid Id, Guid UserId, string FirstName, string LastName, string Email, DateTimeOffset RequestedAt);
