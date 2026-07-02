using System.Security.Claims;
using System.Security.Cryptography;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StudyFlow.Api.Contracts;
using StudyFlow.Application.Notifications;
using StudyFlow.Application.Security;
using StudyFlow.Domain.Notifications;
using StudyFlow.Domain.Users;
using StudyFlow.Infrastructure.Identity;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/notifications")]
public sealed class NotificationsController(
    UserManager<ApplicationUser> userManager,
    StudyFlowDbContext dbContext,
    INotificationReminderPlanner reminderPlanner,
    ISensitiveDataProtector protector) : ControllerBase
{
    private static readonly int[] AllowedCourseReminderMinutes = [0, 5, 10, 15, 30, 60];
    private const string NotificationDeviceTokenPurpose = "notification-device-token";

    [HttpGet("preferences")]
    public async Task<ActionResult<NotificationSettingsResponse>> GetPreferences(CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();

        var settings = await GetOrCreateNotificationSettingsAsync(user.Id, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);

        return Ok(ToNotificationSettingsResponse(settings));
    }

    [HttpPut("preferences")]
    public async Task<ActionResult<NotificationSettingsResponse>> UpdatePreferences(
        NotificationSettingsRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();

        var validationProblem = ValidateNotificationSettings(request);
        if (validationProblem is not null) return validationProblem;

        var settings = await GetOrCreateNotificationSettingsAsync(user.Id, cancellationToken);
        settings.CoursesEnabled = request.CoursesEnabled;
        settings.HomeworkEnabled = request.HomeworkEnabled;
        settings.ApprenticeshipsEnabled = request.ApprenticeshipsEnabled;
        settings.CourseReminderMinutes = request.CourseReminderMinutes;

        await dbContext.SaveChangesAsync(cancellationToken);
        return Ok(ToNotificationSettingsResponse(settings));
    }

    [HttpGet("devices")]
    public async Task<ActionResult<IReadOnlyCollection<NotificationDeviceResponse>>> ListDevices(
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();

        var devices = await dbContext.NotificationDevices
            .AsNoTracking()
            .Where(x => x.UserId == user.Id)
            .OrderByDescending(x => x.LastSeenAt)
            .ToListAsync(cancellationToken);

        return Ok(devices.Select(ToDeviceResponse).ToArray());
    }

    [HttpPost("devices")]
    public async Task<ActionResult<NotificationDeviceResponse>> RegisterDevice(
        NotificationDeviceRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();

        var token = request.Token.Trim();
        if (string.IsNullOrWhiteSpace(token)) return BadRequestProblem("Le token de notification est obligatoire.");

        var platform = ParsePlatform(request.Platform);
        if (platform is null) return BadRequestProblem("Plateforme invalide. Valeurs possibles : android, ios, web.");

        var tokenHash = protector.ComputeLookupHash(token, NotificationDeviceTokenPurpose);
        var device = await dbContext.NotificationDevices
            .SingleOrDefaultAsync(x => x.TokenHash == tokenHash, cancellationToken);

        if (device is null)
        {
            device = new NotificationDevice { TokenHash = tokenHash };
            dbContext.NotificationDevices.Add(device);
        }

        // A push token identifies one current installation. If it is reused after a login,
        // we safely attach it to the current user instead of creating duplicates.
        device.UserId = user.Id;
        device.EncryptedToken = protector.Protect(token, NotificationDeviceTokenPurpose);
        device.Platform = platform.Value;
        device.LastSeenAt = DateTimeOffset.UtcNow;

        await dbContext.SaveChangesAsync(cancellationToken);

        return Ok(ToDeviceResponse(device));
    }

    [HttpDelete("devices/{id:guid}")]
    public async Task<IActionResult> DeleteDevice(Guid id, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();

        var device = await dbContext.NotificationDevices
            .SingleOrDefaultAsync(x => x.Id == id && x.UserId == user.Id, cancellationToken);
        if (device is null) return NotFound();

        dbContext.NotificationDevices.Remove(device);
        await dbContext.SaveChangesAsync(cancellationToken);

        return NoContent();
    }

    [Authorize(Roles = nameof(UserRole.Delegue))]
    [HttpGet("due-preview")]
    public async Task<ActionResult<IReadOnlyCollection<NotificationReminderCandidateResponse>>> GetDuePreview(
        [FromQuery] int lookBehindMinutes = 5,
        [FromQuery] int lookAheadMinutes = 60,
        CancellationToken cancellationToken = default)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        if (lookBehindMinutes is < 0 or > 1440) return BadRequestProblem("lookBehindMinutes doit être entre 0 et 1440.");
        if (lookAheadMinutes is < 1 or > 1440) return BadRequestProblem("lookAheadMinutes doit être entre 1 et 1440.");

        var now = DateTimeOffset.Now;
        var reminders = await reminderPlanner.PlanClassRemindersAsync(
            user.SchoolClassId.Value,
            now.AddMinutes(-lookBehindMinutes),
            now.AddMinutes(lookAheadMinutes),
            cancellationToken);

        return Ok(reminders.Select(ToReminderResponse).ToArray());
    }

    private async Task<NotificationPreference> GetOrCreateNotificationSettingsAsync(
        Guid userId,
        CancellationToken cancellationToken)
    {
        var settings = await dbContext.NotificationPreferences.SingleOrDefaultAsync(x => x.UserId == userId, cancellationToken);
        if (settings is not null) return settings;

        settings = new NotificationPreference { UserId = userId };
        dbContext.NotificationPreferences.Add(settings);
        return settings;
    }

    private ObjectResult? ValidateNotificationSettings(NotificationSettingsRequest request)
    {
        return AllowedCourseReminderMinutes.Contains(request.CourseReminderMinutes)
            ? null
            : BadRequestProblem("Le rappel de cours doit valoir 0, 5, 10, 15, 30 ou 60 minutes.");
    }

    private async Task<ApplicationUser?> CurrentUserAsync() =>
        await userManager.FindByIdAsync(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    private static NotificationPlatform? ParsePlatform(string value) =>
        value.Trim().ToLowerInvariant() switch
        {
            "android" => NotificationPlatform.Android,
            "ios" => NotificationPlatform.Ios,
            "web" => NotificationPlatform.Web,
            _ => null
        };

    private static NotificationSettingsResponse ToNotificationSettingsResponse(NotificationPreference settings) => new(
        settings.CoursesEnabled,
        settings.HomeworkEnabled,
        settings.ApprenticeshipsEnabled,
        settings.CourseReminderMinutes);

    private NotificationDeviceResponse ToDeviceResponse(NotificationDevice device)
    {
        var tokenPreview = "******";
        try
        {
            tokenPreview = ToTokenPreview(protector.Unprotect(device.EncryptedToken, NotificationDeviceTokenPurpose));
        }
        catch (CryptographicException)
        {
            // Local development keys can change. Never leak the encrypted value;
            // show a safe placeholder instead.
        }

        return new NotificationDeviceResponse(
            device.Id,
            device.Platform.ToString().ToLowerInvariant(),
            tokenPreview,
            device.LastSeenAt);
    }

    private static NotificationReminderCandidateResponse ToReminderResponse(NotificationReminderCandidate reminder) => new(
        reminder.Type,
        reminder.UserId,
        reminder.RelatedEntityId,
        reminder.Title,
        reminder.Body,
        reminder.ScheduledAt,
        reminder.DeviceCount);

    private static string ToTokenPreview(string token)
    {
        const int visibleCharacters = 6;
        return token.Length <= visibleCharacters
            ? "******"
            : $"...{token[^visibleCharacters..]}";
    }

    private ObjectResult BadRequestProblem(string title) =>
        BadRequest(new ProblemDetails { Title = title, Status = StatusCodes.Status400BadRequest });
}
