using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using StudyFlow.Api.Contracts;
using StudyFlow.Application.Notifications;
using StudyFlow.Application.Security;
using StudyFlow.Application.Time;
using StudyFlow.Domain.Groups;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Api.Realtime;

/// <summary>
/// Prévient les membres d'un groupe : en temps réel pour ceux qui l'ont ouvert, par
/// notification push pour les autres (sauf en « ne pas déranger »).
/// </summary>
public sealed class StudyGroupNotifier(
    IHubContext<StudyGroupHub> hub,
    StudyGroupConnections connections,
    IPushNotificationSender pushSender,
    StudyFlowDbContext dbContext,
    ISensitiveDataProtector protector,
    ISchoolClock clock,
    ILogger<StudyGroupNotifier> logger)
{
    public const string MessagePurpose = "study-group-message";
    private const int PushBodyMaxLength = 140;

    /// <summary>Ce qui a changé, pour que l'app recharge seulement l'onglet concerné.</summary>
    public static class Areas
    {
        public const string Group = "group";
        public const string Members = "members";
        public const string Tasks = "tasks";
        public const string Resources = "resources";
        public const string Meetings = "meetings";
    }

    public Task ChangedAsync(Guid groupId, string area) =>
        SafeAsync(() => hub.Clients.Group(StudyGroupHub.GroupName(groupId)).SendAsync("changed", groupId, area));

    public Task MessageAsync(StudyGroupMessageResponse message) =>
        SafeAsync(() => hub.Clients.Group(StudyGroupHub.GroupName(message.GroupId)).SendAsync("message", message));

    public Task MessageDeletedAsync(Guid groupId, Guid messageId) =>
        SafeAsync(() => hub.Clients.Group(StudyGroupHub.GroupName(groupId)).SendAsync("messageDeleted", groupId, messageId));

    public Task ReadAsync(Guid groupId, Guid userId, DateTimeOffset readAt) =>
        SafeAsync(() => hub.Clients.Group(StudyGroupHub.GroupName(groupId)).SendAsync("read", groupId, userId, readAt));

    /// <summary>Coupe le temps réel d'un membre qui quitte le groupe ou en est retiré.</summary>
    public async Task DisconnectAsync(Guid groupId, Guid userId)
    {
        foreach (var connectionId in connections.ConnectionsWatching(userId, groupId))
        {
            connections.Unwatch(connectionId, groupId);
            await SafeAsync(() => hub.Groups.RemoveFromGroupAsync(connectionId, StudyGroupHub.GroupName(groupId)));
        }
    }

    /// <summary>Message du système dans la discussion (« Léa a rejoint le groupe »).</summary>
    public async Task SystemMessageAsync(Guid groupId, string text, CancellationToken cancellationToken)
    {
        var message = new StudyGroupMessage
        {
            StudyGroupId = groupId,
            EncryptedText = protector.Protect(text, MessagePurpose),
            CreatedAt = clock.UtcNow
        };
        dbContext.StudyGroupMessages.Add(message);
        await dbContext.SaveChangesAsync(cancellationToken);
        await MessageAsync(new StudyGroupMessageResponse(message.Id, groupId, null, null, text, false, false, message.CreatedAt));
    }

    /// <summary>
    /// Notification push aux destinataires qui n'ont pas le groupe ouvert à l'écran et ne
    /// sont pas en plage calme. Une panne de Firebase n'empêche jamais l'action.
    /// </summary>
    public async Task PushAsync(
        Guid groupId,
        IEnumerable<Guid> recipientIds,
        string title,
        string body,
        CancellationToken cancellationToken)
    {
        var now = clock.UtcNow;
        var candidates = recipientIds.Distinct().Where(x => !connections.IsUserWatching(x, groupId)).ToList();
        if (candidates.Count == 0) return;

        var quiet = (await dbContext.NotificationPreferences
                .AsNoTracking()
                .Where(x => candidates.Contains(x.UserId) && (x.QuietHoursEnabled || x.MutedUntil > now))
                .ToListAsync(cancellationToken))
            .Where(x => x.IsQuietAt(now, clock.TimeZone))
            .Select(x => x.UserId)
            .ToHashSet();
        var recipients = candidates.Where(x => !quiet.Contains(x)).ToList();
        if (recipients.Count == 0) return;

        var shortBody = body.Length <= PushBodyMaxLength ? body : $"{body[..(PushBodyMaxLength - 1)]}…";
        try
        {
            await pushSender.SendAsync(recipients, new PushNotification("group", groupId, title, shortBody), cancellationToken);
        }
        catch (Exception exception) when (!cancellationToken.IsCancellationRequested)
        {
            logger.LogWarning(exception, "Study group {GroupId}: push delivery failed.", groupId);
        }
    }

    private async Task SafeAsync(Func<Task> action)
    {
        try
        {
            await action();
        }
        catch (Exception exception)
        {
            // Le temps réel est un confort : l'enregistrement en base a déjà eu lieu.
            logger.LogWarning(exception, "Study group realtime broadcast failed.");
        }
    }
}
