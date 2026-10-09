using StudyFlow.Domain.Common;

namespace StudyFlow.Domain.School;

public sealed class HomeworkProgress : Entity
{
    public Guid HomeworkId { get; set; }
    public Guid UserId { get; set; }
    public bool IsDone { get; set; }
    public bool NotificationsEnabled { get; set; } = true;

    /// <summary>Délai du rappel avant l'échéance, choisi par chaque élève (la veille par défaut).</summary>
    public int ReminderMinutesBefore { get; set; } = ReminderDefaults.HomeworkMinutes;
    public DateTimeOffset? CompletedAt { get; set; }

    public Homework Homework { get; set; } = null!;
}
