namespace StudyFlow.Application.Security;

public sealed record AuthTokenPair(
    string AccessToken,
    DateTimeOffset AccessTokenExpiresAt,
    string RefreshToken,
    DateTimeOffset RefreshTokenExpiresAt);

public interface IAuthTokenService
{
    Task<AuthTokenPair> IssueAsync(Guid userId, CancellationToken cancellationToken = default);
    Task<AuthTokenPair?> RotateAsync(string refreshToken, CancellationToken cancellationToken = default);
    Task<bool> RevokeAsync(Guid userId, string refreshToken, CancellationToken cancellationToken = default);
}
