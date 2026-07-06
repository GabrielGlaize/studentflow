namespace StudyFlow.Application.Security;

public interface IPasswordResetEmailSender
{
    Task SendPasswordResetAsync(
        string email,
        string resetToken,
        DateTimeOffset expiresAt,
        CancellationToken cancellationToken = default);
}
