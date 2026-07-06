using StudyFlow.Domain.Common;

namespace StudyFlow.Domain.Notifications;

public enum NotificationDeliveryStatus
{
    Sent = 0,
    Failed = 1
}

public sealed class NotificationDelivery : Entity
{
    public Guid UserId { get; set; }
    public string Type { get; set; } = string.Empty;
    public Guid RelatedEntityId { get; set; }
    public DateTimeOffset ScheduledAt { get; set; }
    public NotificationDeliveryStatus Status { get; set; }
    public string? ErrorMessage { get; set; }
    public DateTimeOffset ProcessedAt { get; set; } = DateTimeOffset.UtcNow;
}
