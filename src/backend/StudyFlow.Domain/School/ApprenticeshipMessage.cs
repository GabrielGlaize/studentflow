using StudyFlow.Domain.Common;

namespace StudyFlow.Domain.School;

public sealed class ApprenticeshipMessage : Entity, ISoftDeletable
{
    public Guid SchoolClassId { get; set; }
    public Guid AuthorId { get; set; }
    public string EncryptedContent { get; set; } = string.Empty;
    public string? EncryptedLink { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? DeletedAt { get; set; }
    public Guid? DeletedById { get; set; }

    public SchoolClass SchoolClass { get; set; } = null!;
}
