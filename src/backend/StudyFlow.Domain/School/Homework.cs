using StudyFlow.Domain.Common;

namespace StudyFlow.Domain.School;

public sealed class Homework : AuditableEntity, ISoftDeletable
{
    public Guid SchoolClassId { get; set; }
    public Guid? CourseId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public DateTimeOffset Deadline { get; set; }
    public Guid CreatedById { get; set; }
    public Guid? UpdatedById { get; set; }
    public DateTimeOffset? DeletedAt { get; set; }

    public SchoolClass SchoolClass { get; set; } = null!;
    public Course? Course { get; set; }
    public ICollection<HomeworkProgress> ProgressItems { get; set; } = [];
}
