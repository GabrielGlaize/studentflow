using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StudyFlow.Api.Contracts;
using StudyFlow.Api.Realtime;
using StudyFlow.Application.Security;
using StudyFlow.Application.Time;
using StudyFlow.Domain.Groups;
using StudyFlow.Infrastructure.Identity;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Api.Controllers;

/// <summary>
/// Discussion d'un groupe. Le message est enregistré (chiffré) puis diffusé en temps réel aux
/// membres qui ont le groupe ouvert ; les autres reçoivent une notification.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/groups")]
public sealed class StudyGroupMessagesController(
    UserManager<ApplicationUser> userManager,
    StudyFlowDbContext dbContext,
    ISensitiveDataProtector protector,
    ISchoolClock clock,
    StudyGroupNotifier notifier)
    : StudyGroupControllerBase(userManager, dbContext, protector, clock, notifier)
{
    private const int PageSize = 50;

    /// <summary>Les messages les plus récents, ou ceux d'avant <paramref name="before"/> pour remonter le fil.</summary>
    [HttpGet("{id:guid}/messages")]
    public async Task<ActionResult<IReadOnlyCollection<StudyGroupMessageResponse>>> List(
        Guid id,
        [FromQuery] DateTimeOffset? before,
        [FromQuery] DateTimeOffset? after,
        CancellationToken cancellationToken)
    {
        var access = await AccessAsync(id, cancellationToken);
        if (access is null) return NotFound();

        var query = Db.StudyGroupMessages.AsNoTracking().Where(x => x.StudyGroupId == id);
        if (before is { } beforeAt) query = query.Where(x => x.CreatedAt < beforeAt);
        if (after is { } afterAt) query = query.Where(x => x.CreatedAt > afterAt);

        var messages = after is null
            ? await query.OrderByDescending(x => x.CreatedAt).Take(PageSize).ToListAsync(cancellationToken)
            : await query.OrderBy(x => x.CreatedAt).Take(PageSize * 4).ToListAsync(cancellationToken);
        var names = await NamesAsync(messages.Where(x => x.AuthorId != null).Select(x => x.AuthorId!.Value), cancellationToken);

        return Ok(messages
            .OrderBy(x => x.CreatedAt)
            .Select(x => ToResponse(x, names, access.User.Id))
            .ToArray());
    }

    [HttpPost("{id:guid}/messages")]
    public async Task<ActionResult<StudyGroupMessageResponse>> Send(Guid id, StudyGroupMessageRequest request, CancellationToken cancellationToken)
    {
        var access = await AccessAsync(id, cancellationToken);
        if (access is null) return NotFound();
        if (access.Group.IsArchivedAt(Clock.UtcNow)) return ArchivedProblem();

        var text = request.Text.Trim();
        if (text.Length == 0) return BadRequestProblem("Écris un message.");

        var now = Clock.UtcNow;
        var message = new StudyGroupMessage
        {
            StudyGroupId = id,
            AuthorId = access.User.Id,
            EncryptedText = Protector.Protect(text, StudyGroupNotifier.MessagePurpose),
            CreatedAt = now
        };
        Db.StudyGroupMessages.Add(message);
        access.Member.LastReadAt = now;
        await Db.SaveChangesAsync(cancellationToken);

        var authorName = StudentNames.Short(access.User.FirstName, access.User.LastName);
        var response = new StudyGroupMessageResponse(message.Id, id, access.User.Id, authorName, text, false, false, now);
        await Notifier.MessageAsync(response);
        await Notifier.PushAsync(
            id,
            ActiveMemberIds(access.Group).Where(x => x != access.User.Id),
            access.Group.Name,
            $"{authorName} : {text}",
            cancellationToken);

        return Ok(response with { IsMine = true });
    }

    /// <summary>L'auteur retire son message : il reste une trace « message supprimé ».</summary>
    [HttpDelete("messages/{messageId:guid}")]
    public async Task<IActionResult> Delete(Guid messageId, CancellationToken cancellationToken)
    {
        var message = await Db.StudyGroupMessages.SingleOrDefaultAsync(x => x.Id == messageId, cancellationToken);
        if (message is null) return NotFound();
        var access = await AccessAsync(message.StudyGroupId, cancellationToken);
        if (access is null) return NotFound();
        if (message.AuthorId != access.User.Id) return Forbid();

        message.DeletedAt = Clock.UtcNow;
        message.EncryptedText = Protector.Protect("—", StudyGroupNotifier.MessagePurpose);
        await Db.SaveChangesAsync(cancellationToken);
        await Notifier.MessageDeletedAsync(message.StudyGroupId, message.Id);
        return NoContent();
    }

    private StudyGroupMessageResponse ToResponse(StudyGroupMessage message, IReadOnlyDictionary<Guid, string> names, Guid userId)
    {
        var isDeleted = message.DeletedAt is not null;
        return new StudyGroupMessageResponse(
            message.Id,
            message.StudyGroupId,
            message.AuthorId,
            message.AuthorId is { } authorId ? names.GetValueOrDefault(authorId, "Ancien élève") : null,
            isDeleted ? string.Empty : Protector.Unprotect(message.EncryptedText, StudyGroupNotifier.MessagePurpose),
            message.AuthorId == userId,
            isDeleted,
            message.CreatedAt);
    }
}
