namespace StudyFlow.Application.Security;

public sealed record PasswordResetRequestResult(
    bool IsAccepted,
    string? DevelopmentToken = null,
    DateTimeOffset? ExpiresAt = null);

public interface IPasswordResetService
{
    Task<PasswordResetRequestResult> RequestResetAsync(
        string email,
        CancellationToken cancellationToken = default);

    Task<bool> ResetPasswordAsync(
        string email,
        string resetToken,
        string newPassword,
        CancellationToken cancellationToken = default);
}
