using StudyFlow.Application.Notifications;

namespace StudyFlow.Infrastructure.Notifications;

public interface INotificationSender
{
    Task SendAsync(NotificationReminderCandidate reminder, CancellationToken cancellationToken);
}
