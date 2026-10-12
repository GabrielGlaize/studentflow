using System.Collections.Concurrent;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using StudyFlow.Domain.Groups;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Api.Realtime;

/// <summary>
/// Connexion temps réel des groupes de travail. L'app ouvre un groupe avec <see cref="Join"/> :
/// elle reçoit alors les nouveaux messages, « … écrit » et les changements (tâches, réunions,
/// ressources) à l'instant. Les messages eux-mêmes sont envoyés par l'API REST, qui les
/// enregistre avant de les diffuser : si la connexion tombe, rien ne se perd.
/// </summary>
[Authorize]
public sealed class StudyGroupHub(StudyFlowDbContext dbContext, StudyGroupConnections connections) : Hub
{
    public const string Path = "/hubs/groups";

    public static string GroupName(Guid groupId) => $"study-group:{groupId:N}";

    public override Task OnConnectedAsync()
    {
        connections.Add(Context.ConnectionId, CurrentUserId);
        return base.OnConnectedAsync();
    }

    public override Task OnDisconnectedAsync(Exception? exception)
    {
        connections.Remove(Context.ConnectionId);
        return base.OnDisconnectedAsync(exception);
    }

    /// <summary>Suit un groupe dont l'élève est membre actif. Faux sinon.</summary>
    public async Task<bool> Join(Guid groupId)
    {
        var userId = CurrentUserId;
        var isMember = await dbContext.StudyGroupMembers
            .AsNoTracking()
            .AnyAsync(x => x.StudyGroupId == groupId
                && x.UserId == userId
                && x.Status == StudyGroupMemberStatus.Active
                && dbContext.Users.Any(user => user.Id == userId
                    && user.IsActive
                    && user.SchoolClassId == x.Group.SchoolClassId));
        if (!isMember) return false;

        await Groups.AddToGroupAsync(Context.ConnectionId, GroupName(groupId));
        connections.Watch(Context.ConnectionId, groupId);
        return true;
    }

    public async Task Leave(Guid groupId)
    {
        connections.Unwatch(Context.ConnectionId, groupId);
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, GroupName(groupId));
    }

    /// <summary>« Léa écrit… » : relayé aux autres membres qui ont le groupe ouvert.</summary>
    public async Task Typing(Guid groupId)
    {
        if (!connections.IsWatching(Context.ConnectionId, groupId)) return;
        await Clients.OthersInGroup(GroupName(groupId)).SendAsync("typing", groupId, CurrentUserId);
    }

    private Guid CurrentUserId => Guid.Parse(Context.User!.FindFirstValue(ClaimTypes.NameIdentifier)!);
}

/// <summary>
/// Qui a quel groupe ouvert, sur quelle connexion. Sert à ne pas envoyer de notification push
/// à quelqu'un qui lit déjà la discussion, et à couper l'accès d'un membre retiré.
/// </summary>
public sealed class StudyGroupConnections
{
    private readonly ConcurrentDictionary<string, Connection> _connections = new();

    public void Add(string connectionId, Guid userId) => _connections[connectionId] = new Connection(userId);

    public void Remove(string connectionId) => _connections.TryRemove(connectionId, out _);

    public void Watch(string connectionId, Guid groupId)
    {
        if (_connections.TryGetValue(connectionId, out var connection)) connection.Groups[groupId] = 0;
    }

    public void Unwatch(string connectionId, Guid groupId)
    {
        if (_connections.TryGetValue(connectionId, out var connection)) connection.Groups.TryRemove(groupId, out _);
    }

    public bool IsWatching(string connectionId, Guid groupId) =>
        _connections.TryGetValue(connectionId, out var connection) && connection.Groups.ContainsKey(groupId);

    public bool IsUserWatching(Guid userId, Guid groupId) =>
        _connections.Values.Any(x => x.UserId == userId && x.Groups.ContainsKey(groupId));

    public IReadOnlyList<string> ConnectionsWatching(Guid userId, Guid groupId) =>
        _connections
            .Where(x => x.Value.UserId == userId && x.Value.Groups.ContainsKey(groupId))
            .Select(x => x.Key)
            .ToList();

    private sealed record Connection(Guid UserId)
    {
        public ConcurrentDictionary<Guid, byte> Groups { get; } = new();
    }
}
