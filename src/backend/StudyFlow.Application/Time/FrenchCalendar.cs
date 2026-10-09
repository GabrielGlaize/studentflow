namespace StudyFlow.Application.Time;

/// <summary>
/// Dates en français pour les messages. L'image Docker (Alpine) tourne sans ICU :
/// <c>CultureInfo("fr-FR")</c> y donnerait des noms anglais.
/// </summary>
public static class FrenchCalendar
{
    private static readonly string[] Weekdays =
        ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"];

    /// <summary>« jeudi 15/10 ».</summary>
    public static string ShortDay(DateOnly day) => $"{Weekdays[(int)day.DayOfWeek]} {day:dd/MM}";

    /// <summary>« 08:30 ».</summary>
    public static string Time(TimeOnly time) => time.ToString("HH:mm");
}
