using StudyFlow.Domain.Common;

namespace StudyFlow.Domain.School;

public sealed class Subject : Entity
{
    public Guid SchoolClassId { get; set; }
    public string Name { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;
    public Guid CreatedById { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    public SchoolClass SchoolClass { get; set; } = null!;
    public ICollection<Course> Courses { get; set; } = [];
}
