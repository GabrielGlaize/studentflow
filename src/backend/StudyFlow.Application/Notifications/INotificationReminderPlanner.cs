namespace StudyFlow.Application.Notifications;

public interface INotificationReminderPlanner
{
    Task<IReadOnlyCollection<NotificationReminderCandidate>> PlanClassRemindersAsync(
        Guid schoolClassId,
        DateTimeOffset windowStart,
        DateTimeOffset windowEnd,
        CancellationToken cancellationToken);
}

public sealed record NotificationReminderCandidate(
    string Type,
    Guid UserId,
    Guid RelatedEntityId,
    string Title,
    string Body,
    DateTimeOffset ScheduledAt,
    int DeviceCount);
