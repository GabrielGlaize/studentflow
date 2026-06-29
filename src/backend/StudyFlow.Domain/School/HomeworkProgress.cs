using StudyFlow.Domain.Common;

namespace StudyFlow.Domain.School;

public sealed class HomeworkProgress : Entity
{
    public Guid HomeworkId { get; set; }
    public Guid UserId { get; set; }
    public bool IsDone { get; set; }
    public bool NotificationsEnabled { get; set; } = true;
    public DateTimeOffset? CompletedAt { get; set; }

    public Homework Homework { get; set; } = null!;
}
