using Microsoft.Extensions.Logging;
using StudyFlow.Application.Notifications;

namespace StudyFlow.Infrastructure.Notifications;

/// <summary>Utilisé tant que Firebase n'est pas configuré (développement, tests).</summary>
public sealed class LoggingPushNotificationSender(
    ILogger<LoggingPushNotificationSender> logger) : IPushNotificationSender
{
    public Task SendAsync(
        IReadOnlyCollection<Guid> userIds,
        PushNotification notification,
        CancellationToken cancellationToken)
    {
        logger.LogInformation(
            "Push notification not sent (Firebase is not configured): {Type} for {UserCount} user(s), entity {RelatedEntityId}.",
            notification.Type,
            userIds.Count,
            notification.RelatedEntityId);

        return Task.CompletedTask;
    }
}
