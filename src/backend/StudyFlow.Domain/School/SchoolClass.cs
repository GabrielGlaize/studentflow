using StudyFlow.Domain.Common;

namespace StudyFlow.Domain.School;

public sealed class SchoolClass : AuditableEntity
{
    public string Name { get; set; } = string.Empty;
    public string SchoolYear { get; set; } = string.Empty;
    public string AccessCodeHash { get; set; } = string.Empty;
    public string EncryptedAccessCode { get; set; } = string.Empty;
    public DateTimeOffset AccessCodeUpdatedAt { get; set; } = DateTimeOffset.UtcNow;
    public bool IsActive { get; set; } = true;
    public Guid CreatedById { get; set; }

    public ICollection<Subject> Subjects { get; set; } = [];
    public ICollection<Teacher> Teachers { get; set; } = [];
    public ICollection<Course> Courses { get; set; } = [];
    public ICollection<Homework> Homeworks { get; set; } = [];
    public ICollection<ClassAnnouncement> Announcements { get; set; } = [];
    public ICollection<ClassMembershipRequest> MembershipRequests { get; set; } = [];
    public ICollection<ApprenticeshipMessage> ApprenticeshipMessages { get; set; } = [];
}
