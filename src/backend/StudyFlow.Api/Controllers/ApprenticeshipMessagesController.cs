using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StudyFlow.Api.Contracts;
using StudyFlow.Application.Security;
using StudyFlow.Domain.School;
using StudyFlow.Domain.Users;
using StudyFlow.Infrastructure.Identity;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/apprenticeship-messages")]
public sealed class ApprenticeshipMessagesController(
    UserManager<ApplicationUser> userManager,
    StudyFlowDbContext dbContext,
    ISensitiveDataProtector protector) : ControllerBase
{
    private const string ContentPurpose = "apprenticeship-message-content";
    private const string LinkPurpose = "apprenticeship-message-link";

    [HttpGet]
    public async Task<ActionResult<IReadOnlyCollection<ApprenticeshipMessageResponse>>> List(
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var messages = await dbContext.ApprenticeshipMessages
            .AsNoTracking()
            .Where(x => x.SchoolClassId == user.SchoolClassId && x.DeletedAt == null)
            .OrderByDescending(x => x.CreatedAt)
            .Take(50)
            .ToListAsync(cancellationToken);

        return Ok(await ToResponsesAsync(messages, cancellationToken));
    }

    [HttpPost]
    public async Task<ActionResult<ApprenticeshipMessageResponse>> Create(
        ApprenticeshipMessageRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var content = CleanRequired(request.Content);
        if (content is null) return BadRequestProblem("Le message est obligatoire.");

        // Le fil alternance peut contenir des contacts ou liens sensibles : le contenu est chiffre en base.
        var message = new ApprenticeshipMessage
        {
            SchoolClassId = user.SchoolClassId.Value,
            AuthorId = user.Id,
            EncryptedContent = protector.Protect(content, ContentPurpose),
            EncryptedLink = ProtectOptional(request.Link, LinkPurpose)
        };

        dbContext.ApprenticeshipMessages.Add(message);
        await dbContext.SaveChangesAsync(cancellationToken);

        return CreatedAtAction(nameof(List), (await ToResponsesAsync([message], cancellationToken)).Single());
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var message = await dbContext.ApprenticeshipMessages
            .SingleOrDefaultAsync(x => x.Id == id
                && x.SchoolClassId == user.SchoolClassId
                && x.DeletedAt == null, cancellationToken);
        if (message is null) return NotFound();

        var canDelete = message.AuthorId == user.Id || User.IsInRole(nameof(UserRole.Delegue));
        if (!canDelete) return Forbid();

        message.DeletedAt = DateTimeOffset.UtcNow;
        message.DeletedById = user.Id;
        await dbContext.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    private async Task<IReadOnlyCollection<ApprenticeshipMessageResponse>> ToResponsesAsync(
        IReadOnlyCollection<ApprenticeshipMessage> messages,
        CancellationToken cancellationToken)
    {
        var authorIds = messages.Select(x => x.AuthorId).Distinct().ToArray();
        var authors = await dbContext.Users
            .AsNoTracking()
            .Where(x => authorIds.Contains(x.Id))
            .ToDictionaryAsync(x => x.Id, x => $"{x.FirstName} {x.LastName}".Trim(), cancellationToken);

        return messages.Select(x => new ApprenticeshipMessageResponse(
            x.Id,
            protector.Unprotect(x.EncryptedContent, ContentPurpose),
            UnprotectOptional(x.EncryptedLink, LinkPurpose),
            x.AuthorId,
            authors.GetValueOrDefault(x.AuthorId, "Utilisateur inconnu"),
            x.CreatedAt)).ToArray();
    }

    private async Task<ApplicationUser?> CurrentUserAsync() =>
        await userManager.FindByIdAsync(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    private string? ProtectOptional(string? value, string purpose) =>
        string.IsNullOrWhiteSpace(value) ? null : protector.Protect(value.Trim(), purpose);

    private string? UnprotectOptional(string? value, string purpose) =>
        string.IsNullOrWhiteSpace(value) ? null : protector.Unprotect(value, purpose);

    private static string? CleanRequired(string value)
    {
        var clean = value.Trim();
        return string.IsNullOrWhiteSpace(clean) ? null : clean;
    }

    private ObjectResult BadRequestProblem(string title) =>
        BadRequest(new ProblemDetails { Title = title, Status = StatusCodes.Status400BadRequest });
}
