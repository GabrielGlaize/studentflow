using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StudyFlow.Api.Contracts;
using StudyFlow.Application.Support;
using StudyFlow.Domain.Support;
using StudyFlow.Infrastructure.Identity;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Api.Controllers;

/// <summary>Idées et bugs remontés depuis l'app : gardés en base et envoyés par e-mail.</summary>
[ApiController]
[Authorize]
[Route("api/v1/feedback")]
public sealed class FeedbackController(
    UserManager<ApplicationUser> userManager,
    StudyFlowDbContext dbContext,
    IFeedbackNotifier notifier,
    ILogger<FeedbackController> logger) : StudyFlowControllerBase(userManager)
{
    private const int MaxPerHour = 10;

    [HttpPost]
    public async Task<IActionResult> Send(FeedbackRequest request, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();

        var kind = request.Kind.Trim().ToLowerInvariant() switch
        {
            "idea" => FeedbackKind.Idea,
            "bug" => FeedbackKind.Bug,
            _ => (FeedbackKind?)null
        };
        if (kind is null) return BadRequestProblem("Choisis « idée » ou « bug ».");

        var message = request.Message?.Trim();
        if (string.IsNullOrEmpty(message) || message.Length < 5)
        {
            return BadRequestProblem("Décris ton idée ou le bug en quelques mots.");
        }

        var since = DateTimeOffset.UtcNow.AddHours(-1);
        var recent = await dbContext.FeedbackItems
            .CountAsync(x => x.UserId == user.Id && x.CreatedAt > since, cancellationToken);
        if (recent >= MaxPerHour)
        {
            return StatusCode(StatusCodes.Status429TooManyRequests, new ProblemDetails
            {
                Title = "Beaucoup de messages en peu de temps : réessaie dans un moment.",
                Status = StatusCodes.Status429TooManyRequests
            });
        }

        dbContext.FeedbackItems.Add(new Feedback
        {
            UserId = user.Id,
            Kind = kind.Value,
            Message = message,
            AppVersion = request.AppVersion?.Trim(),
            Platform = request.Platform?.Trim()
        });
        await dbContext.SaveChangesAsync(cancellationToken);

        try
        {
            await notifier.NotifyAsync(
                new FeedbackMessage(
                    kind == FeedbackKind.Bug ? "bug" : "idea",
                    message,
                    $"{user.FirstName} {user.LastName}".Trim(),
                    user.Email ?? "?",
                    request.AppVersion,
                    request.Platform),
                cancellationToken);
        }
        catch (Exception exception) when (!cancellationToken.IsCancellationRequested)
        {
            // Le message est gardé en base : un souci d'e-mail ne doit pas le perdre.
            logger.LogWarning(exception, "Feedback stored but the e-mail could not be sent.");
        }

        return NoContent();
    }
}
