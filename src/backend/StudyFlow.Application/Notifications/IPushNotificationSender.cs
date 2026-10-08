namespace StudyFlow.Application.Notifications;

/// <param name="Type">Catégorie lue par l'application (course, homework, announcement).</param>
/// <param name="RelatedEntityId">Élément à ouvrir quand l'utilisateur touche la notification.</param>
public sealed record PushNotification(string Type, Guid RelatedEntityId, string Title, string Body);

public interface IPushNotificationSender
{
    /// <summary>Envoie la notification à tous les appareils enregistrés de ces utilisateurs.</summary>
    Task SendAsync(IReadOnlyCollection<Guid> userIds, PushNotification notification, CancellationToken cancellationToken);
}
