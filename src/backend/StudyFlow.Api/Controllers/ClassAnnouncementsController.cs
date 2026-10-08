using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StudyFlow.Api.Contracts;
using StudyFlow.Application.Notifications;
using StudyFlow.Domain.School;
using StudyFlow.Domain.Users;
using StudyFlow.Infrastructure.Identity;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/class-announcements")]
public sealed class ClassAnnouncementsController(
    UserManager<ApplicationUser> userManager,
    StudyFlowDbContext dbContext,
    IPushNotificationSender pushSender,
    ILogger<ClassAnnouncementsController> logger) : StudyFlowControllerBase(userManager)
{
    private const int NotificationBodyMaxLength = 140;

    [HttpGet]
    public async Task<ActionResult<IReadOnlyCollection<ClassAnnouncementResponse>>> List(
        [FromQuery] bool pinnedOnly = false,
        CancellationToken cancellationToken = default)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var query = dbContext.ClassAnnouncements
            .AsNoTracking()
            .Where(x => x.SchoolClassId == user.SchoolClassId && x.DeletedAt == null);

        if (pinnedOnly)
        {
            query = query.Where(x => x.IsPinned);
        }

        var announcements = await query
            .OrderByDescending(x => x.IsPinned)
            .ThenByDescending(x => x.UpdatedAt)
            .Take(30)
            .ToListAsync(cancellationToken);

        return Ok(await ToResponsesAsync(announcements, cancellationToken));
    }

    [Authorize(Roles = nameof(UserRole.Delegue))]
    [HttpPost]
    public async Task<ActionResult<ClassAnnouncementResponse>> Create(
        ClassAnnouncementRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var content = CleanContent(request.Content);
        if (content is null) return BadRequestProblem("Le message est obligatoire.");

        var announcement = new ClassAnnouncement
        {
            SchoolClassId = user.SchoolClassId.Value,
            AuthorId = user.Id,
            Content = content,
            IsPinned = request.IsPinned
        };

        dbContext.ClassAnnouncements.Add(announcement);
        await dbContext.SaveChangesAsync(cancellationToken);

        await NotifyClassAsync(announcement, cancellationToken);

        return CreatedAtAction(nameof(List), (await ToResponsesAsync([announcement], cancellationToken)).Single());
    }

    [Authorize(Roles = nameof(UserRole.Delegue))]
    [HttpPut("{id:guid}")]
    public async Task<ActionResult<ClassAnnouncementResponse>> Update(
        Guid id,
        ClassAnnouncementRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var announcement = await dbContext.ClassAnnouncements
            .SingleOrDefaultAsync(x => x.Id == id
                && x.SchoolClassId == user.SchoolClassId
                && x.DeletedAt == null, cancellationToken);
        if (announcement is null) return NotFound();

        var content = CleanContent(request.Content);
        if (content is null) return BadRequestProblem("Le message est obligatoire.");

        announcement.Content = content;
        announcement.IsPinned = request.IsPinned;
        announcement.UpdatedAt = DateTimeOffset.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);

        return Ok((await ToResponsesAsync([announcement], cancellationToken)).Single());
    }

    [Authorize(Roles = nameof(UserRole.Delegue))]
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var announcement = await dbContext.ClassAnnouncements
            .SingleOrDefaultAsync(x => x.Id == id
                && x.SchoolClassId == user.SchoolClassId
                && x.DeletedAt == null, cancellationToken);
        if (announcement is null) return NotFound();

        announcement.DeletedAt = DateTimeOffset.UtcNow;
        announcement.UpdatedAt = DateTimeOffset.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    private async Task<IReadOnlyCollection<ClassAnnouncementResponse>> ToResponsesAsync(
        IReadOnlyCollection<ClassAnnouncement> announcements,
        CancellationToken cancellationToken)
    {
        var authorIds = announcements.Select(x => x.AuthorId).Distinct().ToArray();
        var authors = await dbContext.Users
            .AsNoTracking()
            .Where(x => authorIds.Contains(x.Id))
            .ToDictionaryAsync(x => x.Id, x => $"{x.FirstName} {x.LastName}".Trim(), cancellationToken);

        return announcements.Select(x => new ClassAnnouncementResponse(
            x.Id,
            x.Content,
            x.IsPinned,
            x.AuthorId,
            authors.GetValueOrDefault(x.AuthorId, "Utilisateur inconnu"),
            x.CreatedAt,
            x.UpdatedAt)).ToArray();
    }

    private async Task NotifyClassAsync(ClassAnnouncement announcement, CancellationToken cancellationToken)
    {
        var recipients = await dbContext.Users
            .Where(x => x.SchoolClassId == announcement.SchoolClassId && x.IsActive && x.Id != announcement.AuthorId)
            .Select(x => x.Id)
            .ToListAsync(cancellationToken);

        var body = announcement.Content.Length <= NotificationBodyMaxLength
            ? announcement.Content
            : $"{announcement.Content[..(NotificationBodyMaxLength - 1)]}…";

        try
        {
            await pushSender.SendAsync(
                recipients,
                new PushNotification(
                    "announcement",
                    announcement.Id,
                    announcement.IsPinned ? "Annonce épinglée" : "Nouvelle annonce de la classe",
                    body),
                cancellationToken);
        }
        catch (Exception exception) when (!cancellationToken.IsCancellationRequested)
        {
            // L'annonce est publiée même si Firebase est momentanément indisponible.
            logger.LogWarning(exception, "Announcement {AnnouncementId} was saved but push delivery failed.", announcement.Id);
        }
    }

    private static string? CleanContent(string content)
    {
        var clean = content.Trim();
        return string.IsNullOrWhiteSpace(clean) ? null : clean;
    }
}
