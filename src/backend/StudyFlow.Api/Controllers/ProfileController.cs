using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StudyFlow.Api.Contracts;
using StudyFlow.Domain.Notifications;
using StudyFlow.Domain.Users;
using StudyFlow.Infrastructure.Identity;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/profile")]
public sealed class ProfileController(
    UserManager<ApplicationUser> userManager,
    StudyFlowDbContext dbContext) : ControllerBase
{
    private static readonly int[] AllowedCourseReminderMinutes = [0, 5, 10, 15, 30, 60];

    [HttpGet]
    public async Task<ActionResult<ProfileResponse>> Get(CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();

        return Ok(await ToProfileResponseAsync(user, cancellationToken));
    }

    [HttpPut]
    public async Task<ActionResult<ProfileResponse>> UpdateProfile(
        UpdateProfileRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();

        var firstName = request.FirstName.Trim();
        var lastName = request.LastName.Trim();
        if (string.IsNullOrWhiteSpace(firstName)) return BadRequestProblem("Le prenom est obligatoire.");
        if (string.IsNullOrWhiteSpace(lastName)) return BadRequestProblem("Le nom est obligatoire.");

        user.FirstName = firstName;
        user.LastName = lastName;
        user.UpdatedAt = DateTimeOffset.UtcNow;

        await dbContext.SaveChangesAsync(cancellationToken);
        return Ok(await ToProfileResponseAsync(user, cancellationToken));
    }

    [HttpPut("app-settings")]
    public async Task<ActionResult<AppSettingsResponse>> UpdateAppSettings(
        AppSettingsRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();

        var theme = ParseTheme(request.Theme);
        if (theme is null) return BadRequestProblem("Theme invalide.");

        var professionalMode = ParseProfessionalMode(request.ProfessionalMode);
        if (professionalMode is null) return BadRequestProblem("Mode professionnel invalide.");

        var settings = await GetOrCreateAppSettingsAsync(user.Id, cancellationToken);
        settings.Theme = theme.Value;
        settings.HasCompany = request.HasCompany;
        settings.CompanyName = request.HasCompany ? CleanOptional(request.CompanyName) : null;
        settings.ProfessionalMode = request.HasCompany ? professionalMode.Value : ProfessionalMode.Apprenticeship;
        settings.UpdatedAt = DateTimeOffset.UtcNow;

        await dbContext.SaveChangesAsync(cancellationToken);
        return Ok(ToAppSettingsResponse(settings));
    }

    [HttpPut("notification-settings")]
    public async Task<ActionResult<NotificationSettingsResponse>> UpdateNotificationSettings(
        NotificationSettingsRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();

        if (!AllowedCourseReminderMinutes.Contains(request.CourseReminderMinutes))
        {
            return BadRequestProblem("Le rappel de cours doit valoir 0, 5, 10, 15, 30 ou 60 minutes.");
        }

        var settings = await GetOrCreateNotificationSettingsAsync(user.Id, cancellationToken);
        settings.CoursesEnabled = request.CoursesEnabled;
        settings.HomeworkEnabled = request.HomeworkEnabled;
        settings.ApprenticeshipsEnabled = request.ApprenticeshipsEnabled;
        settings.CourseReminderMinutes = request.CourseReminderMinutes;

        await dbContext.SaveChangesAsync(cancellationToken);
        return Ok(ToNotificationSettingsResponse(settings));
    }

    private async Task<ProfileResponse> ToProfileResponseAsync(
        ApplicationUser user,
        CancellationToken cancellationToken)
    {
        var appSettings = await GetOrCreateAppSettingsAsync(user.Id, cancellationToken);
        var notificationSettings = await GetOrCreateNotificationSettingsAsync(user.Id, cancellationToken);
        var roles = await userManager.GetRolesAsync(user);

        await dbContext.SaveChangesAsync(cancellationToken);

        return new ProfileResponse(
            user.Id,
            user.Email ?? string.Empty,
            user.FirstName,
            user.LastName,
            user.SchoolClassId,
            roles.ToArray(),
            ToAppSettingsResponse(appSettings),
            ToNotificationSettingsResponse(notificationSettings));
    }

    private async Task<UserAppSettings> GetOrCreateAppSettingsAsync(Guid userId, CancellationToken cancellationToken)
    {
        var settings = await dbContext.UserAppSettings.SingleOrDefaultAsync(x => x.UserId == userId, cancellationToken);
        if (settings is not null) return settings;

        settings = new UserAppSettings { UserId = userId };
        dbContext.UserAppSettings.Add(settings);
        return settings;
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

    private async Task<ApplicationUser?> CurrentUserAsync() =>
        await userManager.FindByIdAsync(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    private static ThemePreference? ParseTheme(string value) =>
        value.Trim().ToLowerInvariant() switch
        {
            "system" => ThemePreference.System,
            "light" => ThemePreference.Light,
            "dark" => ThemePreference.Dark,
            _ => null
        };

    private static ProfessionalMode? ParseProfessionalMode(string value) =>
        value.Trim().ToLowerInvariant() switch
        {
            "apprenticeship" => ProfessionalMode.Apprenticeship,
            "company" => ProfessionalMode.Company,
            _ => null
        };

    private static AppSettingsResponse ToAppSettingsResponse(UserAppSettings settings) => new(
        settings.Theme.ToString().ToLowerInvariant(),
        settings.HasCompany,
        settings.CompanyName,
        settings.ProfessionalMode.ToString().ToLowerInvariant());

    private static NotificationSettingsResponse ToNotificationSettingsResponse(NotificationPreference settings) => new(
        settings.CoursesEnabled,
        settings.HomeworkEnabled,
        settings.ApprenticeshipsEnabled,
        settings.CourseReminderMinutes);

    private static string? CleanOptional(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private ObjectResult BadRequestProblem(string title) =>
        BadRequest(new ProblemDetails { Title = title, Status = StatusCodes.Status400BadRequest });
}
