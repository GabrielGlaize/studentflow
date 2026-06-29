using StudyFlow.Domain.Common;

namespace StudyFlow.Domain.School;

public enum ClassMembershipRequestStatus
{
    Pending = 0,
    Approved = 1,
    Rejected = 2,
    Cancelled = 3
}

public sealed class ClassMembershipRequest : Entity
{
    public Guid SchoolClassId { get; set; }
    public Guid UserId { get; set; }
    public ClassMembershipRequestStatus Status { get; set; } = ClassMembershipRequestStatus.Pending;
    public DateTimeOffset RequestedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? DecidedAt { get; set; }
    public Guid? DecidedById { get; set; }

    public SchoolClass SchoolClass { get; set; } = null!;
}
