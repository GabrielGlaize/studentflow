namespace StudyFlow.Application.Notifications;

/// <summary>Formule le délai d'un rappel : « dans 15 min », « demain », « dans 2 jours ».</summary>
public static class ReminderWording
{
    private const int Day = 24 * 60;

    public static string Relative(int minutesBefore)
    {
        if (minutesBefore <= 0) return "maintenant";
        if (minutesBefore < 60) return $"dans {minutesBefore} min";
        if (minutesBefore < Day)
        {
            var hours = minutesBefore / 60;
            var rest = minutesBefore % 60;
            return rest == 0 ? $"dans {hours} h" : $"dans {hours} h {rest:00}";
        }

        if (minutesBefore == Day) return "demain";
        if (minutesBefore == 7 * Day) return "dans 1 semaine";

        var days = minutesBefore / Day;
        var leftHours = minutesBefore % Day / 60;
        var dayLabel = days == 1 ? "1 jour" : $"{days} jours";
        return leftHours == 0 ? $"dans {dayLabel}" : $"dans {dayLabel} et {leftHours} h";
    }
}
