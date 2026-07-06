using StudyFlow.Domain.Common;

namespace StudyFlow.Domain.School;

public enum PersonalEventCategory
{
    Apprenticeship = 0,
    Company = 1,
    Personnel = 2
}

public sealed class PersonalEvent : AuditableEntity
{
    public Guid UserId { get; set; }
    public DateOnly Day { get; set; }
    public string EncryptedData { get; set; } = string.Empty;
    public PersonalEventCategory Category { get; set; } = PersonalEventCategory.Apprenticeship;
    public bool NotificationsEnabled { get; set; }
}
