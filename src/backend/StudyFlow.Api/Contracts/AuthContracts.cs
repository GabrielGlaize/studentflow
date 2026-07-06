using StudyFlow.Application.Security;

namespace StudyFlow.Api.Contracts;

public sealed record RegisterRequest(string Email, string Password, string FirstName, string LastName);
public sealed record RegisterAndCreateClassRequest(string Email, string Password, string FirstName, string LastName, string SchoolClassName, string SchoolYear);
public sealed record CreateClassRequest(string SchoolClassName, string SchoolYear);
public sealed record LoginRequest(string Email, string Password);
public sealed record RefreshRequest(string RefreshToken);
public sealed record LogoutRequest(string RefreshToken);
public sealed record ForgotPasswordRequest(string Email);
public sealed record ForgotPasswordResponse(string Message, string? DevelopmentToken = null, DateTimeOffset? ExpiresAt = null);
public sealed record ResetPasswordRequest(string Email, string Token, string NewPassword);
public sealed record AuthResponse(AuthTokenPair Tokens, UserSummary User, string? ClassCode = null);
public sealed record UserSummary(Guid Id, string Email, string FirstName, string LastName, Guid? SchoolClassId, IReadOnlyCollection<string> Roles);

public sealed record JoinClassRequest(string Code);
public sealed record MembershipRequestResponse(Guid Id, string Status, DateTimeOffset RequestedAt);
public sealed record PendingMembershipResponse(Guid Id, Guid UserId, string FirstName, string LastName, string Email, DateTimeOffset RequestedAt);
