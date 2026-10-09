using StudyFlow.Api.Contracts;
using StudyFlow.Domain.Notifications;

namespace StudyFlow.Api.Controllers;

/// <summary>Lecture et mise à jour des réglages de notification, partagées par les deux routes.</summary>
internal static class NotificationSettingsMapper
{
    public static void Apply(NotificationPreference settings, NotificationSettingsRequest request, DateTimeOffset now)
    {
        settings.CoursesEnabled = request.CoursesEnabled;
        settings.HomeworkEnabled = request.HomeworkEnabled;
        settings.ApprenticeshipsEnabled = request.ApprenticeshipsEnabled;
        settings.CourseReminderMinutes = request.CourseReminderMinutes;

        // Champs facultatifs : une ancienne version de l'app ne les envoie pas.
        if (request.QuietHoursEnabled is { } quietHoursEnabled) settings.QuietHoursEnabled = quietHoursEnabled;
        if (request.QuietHoursStart is { } quietHoursStart) settings.QuietHoursStart = quietHoursStart;
        if (request.QuietHoursEnd is { } quietHoursEnd) settings.QuietHoursEnd = quietHoursEnd;
        if (request.MutedUntil is { } mutedUntil)
        {
            settings.MutedUntil = mutedUntil > now ? mutedUntil.ToUniversalTime() : null;
        }
    }

    public static NotificationSettingsResponse ToResponse(NotificationPreference settings, DateTimeOffset now) => new(
        settings.CoursesEnabled,
        settings.HomeworkEnabled,
        settings.ApprenticeshipsEnabled,
        settings.CourseReminderMinutes,
        settings.QuietHoursEnabled,
        settings.QuietHoursStart,
        settings.QuietHoursEnd,
        settings.MutedUntil > now ? settings.MutedUntil : null);
}
