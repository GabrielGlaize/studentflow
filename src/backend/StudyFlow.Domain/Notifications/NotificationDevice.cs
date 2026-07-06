using StudyFlow.Domain.Common;

namespace StudyFlow.Domain.Notifications;

public enum NotificationPlatform
{
    Android = 0,
    Ios = 1,
    Web = 2
}

public sealed class NotificationDevice : Entity
{
    public Guid UserId { get; set; }
    public string TokenHash { get; set; } = string.Empty;
    public string EncryptedToken { get; set; } = string.Empty;
    public NotificationPlatform Platform { get; set; }
    public DateTimeOffset LastSeenAt { get; set; } = DateTimeOffset.UtcNow;
}
