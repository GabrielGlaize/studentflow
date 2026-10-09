namespace StudyFlow.Domain.School;

/// <summary>Délais de rappel proposés par défaut, en minutes avant l'échéance ou le début.</summary>
public static class ReminderDefaults
{
    public const int HomeworkMinutes = 24 * 60;
    public const int TaskMinutes = 24 * 60;
    public const int EventMinutes = 60;

    /// <summary>Un rappel peut être programmé jusqu'à 30 jours à l'avance.</summary>
    public const int MaxMinutes = 30 * 24 * 60;

    public static bool IsValid(int minutes) => minutes is >= 0 and <= MaxMinutes;
}
