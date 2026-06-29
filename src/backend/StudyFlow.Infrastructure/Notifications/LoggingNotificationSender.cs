using Microsoft.Extensions.Logging;
using StudyFlow.Application.Notifications;

namespace StudyFlow.Infrastructure.Notifications;

public sealed class LoggingNotificationSender(
    ILogger<LoggingNotificationSender> logger) : INotificationSender
{
    public Task SendAsync(NotificationReminderCandidate reminder, CancellationToken cancellationToken)
    {
        // This class intentionally does not call Firebase/Web Push yet.
        // It proves that the backend can decide which notifications should be sent.
        logger.LogInformation(
            "Notification planned: {Type} for user {UserId}, entity {RelatedEntityId}, scheduled at {ScheduledAt}, devices: {DeviceCount}",
            reminder.Type,
            reminder.UserId,
            reminder.RelatedEntityId,
            reminder.ScheduledAt,
            reminder.DeviceCount);

        return Task.CompletedTask;
    }
}
