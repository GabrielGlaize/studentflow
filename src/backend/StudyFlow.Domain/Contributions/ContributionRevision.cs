using StudyFlow.Domain.Common;

namespace StudyFlow.Domain.Contributions;

public enum ContributionType
{
    Course = 0,
    Homework = 1
}

public enum ContributionAction
{
    Created = 0,
    Updated = 1,
    Deleted = 2,
    Restored = 3
}

public sealed class ContributionRevision : Entity
{
    public Guid SchoolClassId { get; set; }
    public ContributionType EntityType { get; set; }
    public Guid EntityId { get; set; }
    public ContributionAction Action { get; set; }
    public string EncryptedSnapshot { get; set; } = string.Empty;
    public Guid AuthorId { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
