using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StudyFlow.Api.Contracts;
using StudyFlow.Application.Security;
using StudyFlow.Application.Time;
using StudyFlow.Domain.Notes;
using StudyFlow.Infrastructure.Identity;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Api.Controllers;

/// <summary>
/// Notes du jour : une par jour et par élève, chiffrées en base, synchronisées entre
/// ses appareils. La modification la plus récente l'emporte.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/daily-notes")]
public sealed class DailyNotesController(
    UserManager<ApplicationUser> userManager,
    StudyFlowDbContext dbContext,
    ISensitiveDataProtector protector,
    ISchoolClock clock) : StudyFlowControllerBase(userManager)
{
    private const string TextPurpose = "daily-note-text";

    /// <summary>Historique gardé côté serveur (environ un an et demi de journées notées).</summary>
    private const int MaxNotes = 500;

    [HttpGet]
    public async Task<ActionResult<IReadOnlyCollection<DailyNoteResponse>>> List(CancellationToken cancellationToken)
    {
        var userId = CurrentUserId;
        var notes = await dbContext.DailyNotes
            .AsNoTracking()
            .Where(x => x.UserId == userId)
            .OrderByDescending(x => x.Day)
            .Take(MaxNotes)
            .ToListAsync(cancellationToken);

        return Ok(notes.Select(ToResponse).ToArray());
    }

    [HttpPut("{day}")]
    public async Task<IActionResult> Save(DateOnly day, DailyNoteRequest request, CancellationToken cancellationToken)
    {
        var userId = CurrentUserId;
        if (day > clock.Today.AddDays(1)) return BadRequestProblem("Une note ne peut pas concerner un jour futur.");

        var note = await dbContext.DailyNotes
            .SingleOrDefaultAsync(x => x.UserId == userId && x.Day == day, cancellationToken);

        // Un autre appareil a écrit plus récemment : on garde sa version et on la renvoie.
        if (note is not null && note.UpdatedAt > request.UpdatedAt) return Ok(ToResponse(note));

        if (string.IsNullOrWhiteSpace(request.Text))
        {
            if (note is not null)
            {
                dbContext.DailyNotes.Remove(note);
                await dbContext.SaveChangesAsync(cancellationToken);
            }
            return NoContent();
        }

        if (note is null)
        {
            note = new DailyNote { UserId = userId, Day = day };
            dbContext.DailyNotes.Add(note);
        }

        note.EncryptedText = protector.Protect(request.Text, TextPurpose);
        note.UpdatedAt = request.UpdatedAt.ToUniversalTime();
        note.ReviewedAt = request.ReviewedAt?.ToUniversalTime();
        await dbContext.SaveChangesAsync(cancellationToken);

        return Ok(ToResponse(note));
    }

    [HttpDelete("{day}")]
    public async Task<IActionResult> Delete(DateOnly day, CancellationToken cancellationToken)
    {
        var userId = CurrentUserId;
        await dbContext.DailyNotes
            .Where(x => x.UserId == userId && x.Day == day)
            .ExecuteDeleteAsync(cancellationToken);
        return NoContent();
    }

    private DailyNoteResponse ToResponse(DailyNote note) => new(
        note.Day,
        protector.Unprotect(note.EncryptedText, TextPurpose),
        note.UpdatedAt,
        note.ReviewedAt);
}
