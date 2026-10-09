using StudyFlow.Domain.Common;

namespace StudyFlow.Domain.Notifications;

public sealed class NotificationPreference : Entity
{
    public Guid UserId { get; set; }
    public bool CoursesEnabled { get; set; } = true;
    public bool HomeworkEnabled { get; set; } = true;
    public bool ApprenticeshipsEnabled { get; set; }
    public int CourseReminderMinutes { get; set; } = 5;

    /// <summary>Plage calme quotidienne (heure locale) : aucune notification.</summary>
    public bool QuietHoursEnabled { get; set; }
    public TimeOnly QuietHoursStart { get; set; } = new(22, 0);
    public TimeOnly QuietHoursEnd { get; set; } = new(7, 0);

    /// <summary>Pause ponctuelle : aucune notification jusqu'à cet instant.</summary>
    public DateTimeOffset? MutedUntil { get; set; }

    /// <summary>
    /// Vrai si une notification envoyée à cet instant dérangerait l'élève. La plage
    /// calme peut passer minuit (22 h → 7 h).
    /// </summary>
    public bool IsQuietAt(DateTimeOffset instant, TimeZoneInfo timeZone)
    {
        if (MutedUntil is { } mutedUntil && instant < mutedUntil) return true;
        if (!QuietHoursEnabled || QuietHoursStart == QuietHoursEnd) return false;

        var localTime = TimeOnly.FromDateTime(TimeZoneInfo.ConvertTime(instant, timeZone).DateTime);
        return QuietHoursStart < QuietHoursEnd
            ? localTime >= QuietHoursStart && localTime < QuietHoursEnd
            : localTime >= QuietHoursStart || localTime < QuietHoursEnd;
    }
}
