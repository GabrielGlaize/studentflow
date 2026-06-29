using StudyFlow.Domain.Common;

namespace StudyFlow.Domain.School;

public enum PersonalTaskCategory
{
    School = 0,
    Apprenticeship = 1,
    Company = 2
}

public sealed class PersonalTask : AuditableEntity
{
    public Guid UserId { get; set; }
    public Guid? CourseId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public DateTimeOffset? Deadline { get; set; }
    public bool IsDone { get; set; }
    public bool NotificationsEnabled { get; set; }
    public PersonalTaskCategory Category { get; set; } = PersonalTaskCategory.School;
    public DateTimeOffset? CompletedAt { get; set; }

    public Course? Course { get; set; }
}
