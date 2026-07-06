using StudyFlow.Domain.Common;

namespace StudyFlow.Domain.School;

public sealed class ClassAnnouncement : AuditableEntity, ISoftDeletable
{
    public Guid SchoolClassId { get; set; }
    public Guid AuthorId { get; set; }
    public string Content { get; set; } = string.Empty;
    public bool IsPinned { get; set; }
    public DateTimeOffset? DeletedAt { get; set; }

    public SchoolClass SchoolClass { get; set; } = null!;
}
