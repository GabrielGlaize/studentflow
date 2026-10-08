using System.Security.Cryptography;
using FirebaseAdmin.Messaging;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using StudyFlow.Application.Notifications;
using StudyFlow.Application.Security;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Infrastructure.Notifications;

/// <summary>Envoi réel via Firebase Cloud Messaging (Android, iOS et Web).</summary>
public sealed class FcmPushNotificationSender(
    StudyFlowDbContext dbContext,
    ISensitiveDataProtector protector,
    FirebaseMessaging messaging,
    ILogger<FcmPushNotificationSender> logger) : IPushNotificationSender
{
    // Doit correspondre au canal créé par l'application Flutter.
    public const string AndroidChannelId = "studyflow_reminders";

    private const string DeviceTokenPurpose = "notification-device-token";
    private const int FcmBatchSize = 500;

    public async Task SendAsync(
        IReadOnlyCollection<Guid> userIds,
        PushNotification notification,
        CancellationToken cancellationToken)
    {
        if (userIds.Count == 0) return;

        var devices = await dbContext.NotificationDevices
            .Where(x => userIds.Contains(x.UserId))
            .ToListAsync(cancellationToken);

        var targets = new List<(Domain.Notifications.NotificationDevice Device, string Token)>();
        foreach (var device in devices)
        {
            try
            {
                targets.Add((device, protector.Unprotect(device.EncryptedToken, DeviceTokenPurpose)));
            }
            catch (CryptographicException)
            {
                // Jeton chiffré avec d'anciennes clés : l'appareil se réenregistrera au prochain lancement.
                dbContext.NotificationDevices.Remove(device);
            }
        }

        var failures = 0;
        foreach (var batch in targets.Chunk(FcmBatchSize))
        {
            var response = await messaging.SendEachAsync(
                batch.Select(target => BuildMessage(target.Token, notification)).ToList(),
                cancellationToken);

            for (var index = 0; index < response.Responses.Count; index++)
            {
                var result = response.Responses[index];
                if (result.IsSuccess) continue;

                if (IsDeadToken(result.Exception))
                {
                    // Application désinstallée ou jeton expiré : inutile de réessayer.
                    dbContext.NotificationDevices.Remove(batch[index].Device);
                }
                else
                {
                    failures++;
                    logger.LogWarning(result.Exception, "FCM delivery failed for device {DeviceId}.", batch[index].Device.Id);
                }
            }
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        if (failures > 0 && failures == targets.Count)
        {
            // Le worker marque alors le rappel en échec et le retente au tour suivant.
            throw new InvalidOperationException($"Firebase a refusé les {failures} envois de la notification {notification.Type}.");
        }
    }

    private static Message BuildMessage(string token, PushNotification notification) => new()
    {
        Token = token,
        Notification = new Notification { Title = notification.Title, Body = notification.Body },
        Data = new Dictionary<string, string>
        {
            ["type"] = notification.Type,
            ["relatedEntityId"] = notification.RelatedEntityId.ToString()
        },
        Android = new AndroidConfig
        {
            Priority = Priority.High,
            Notification = new AndroidNotification { ChannelId = AndroidChannelId }
        }
    };

    private static bool IsDeadToken(FirebaseMessagingException? exception) =>
        exception?.MessagingErrorCode is MessagingErrorCode.Unregistered or MessagingErrorCode.InvalidArgument;
}
