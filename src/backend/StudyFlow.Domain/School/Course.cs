using StudyFlow.Domain.Common;

namespace StudyFlow.Domain.School;

public sealed class Course : AuditableEntity, ISoftDeletable
{
    public Guid SchoolClassId { get; set; }
    public Guid? SeriesId { get; set; }
    public Guid SubjectId { get; set; }
    public DateOnly Day { get; set; }
    public string EncryptedData { get; set; } = string.Empty;
    public Guid? TeacherId { get; set; }
    public bool IsCancelled { get; set; }
    public Guid CreatedById { get; set; }
    public Guid? UpdatedById { get; set; }
    public long Version { get; set; } = 1;
    public DateTimeOffset? DeletedAt { get; set; }

    public SchoolClass SchoolClass { get; set; } = null!;
    public Subject Subject { get; set; } = null!;
    public Teacher? Teacher { get; set; }
    public ICollection<Homework> Homeworks { get; set; } = [];
}
