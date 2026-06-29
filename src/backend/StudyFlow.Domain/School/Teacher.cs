using StudyFlow.Domain.Common;

namespace StudyFlow.Domain.School;

public sealed class Teacher : Entity
{
    public Guid SchoolClassId { get; set; }
    public string EncryptedDisplayName { get; set; } = string.Empty;
    public string SearchNameHash { get; set; } = string.Empty;
    public string? EncryptedInformation { get; set; }
    public bool IsActive { get; set; } = true;
    public Guid CreatedById { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    public SchoolClass SchoolClass { get; set; } = null!;
    public ICollection<Course> Courses { get; set; } = [];
}
