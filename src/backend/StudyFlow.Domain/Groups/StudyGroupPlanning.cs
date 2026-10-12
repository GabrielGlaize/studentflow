using StudyFlow.Domain.Common;

namespace StudyFlow.Domain.Groups;

public enum StudyGroupMeetingMode
{
    OnSite = 0,
    Remote = 1
}

public enum StudyGroupMeetingStatus
{
    Proposed = 0,
    Confirmed = 1,
    Cancelled = 2
}

/// <summary>
/// Réunion proposée par un membre. Elle est confirmée quand tous les membres ont répondu
/// « ok » ; elle apparaît alors dans l'agenda de chacun.
/// </summary>
public sealed class StudyGroupMeeting : AuditableEntity
{
    public Guid StudyGroupId { get; set; }
    public DateTimeOffset StartsAt { get; set; }
    public DateTimeOffset EndsAt { get; set; }
    public StudyGroupMeetingMode Mode { get; set; }
    public string? EncryptedPlace { get; set; }
    public Guid? ProposedById { get; set; }
    public StudyGroupMeetingStatus Status { get; set; }

    public StudyGroup Group { get; set; } = null!;
    public ICollection<StudyGroupMeetingVote> Votes { get; set; } = [];
}

public sealed class StudyGroupMeetingVote
{
    public Guid StudyGroupMeetingId { get; set; }
    public Guid UserId { get; set; }
    public bool IsAvailable { get; set; }
    public DateTimeOffset AnsweredAt { get; set; } = DateTimeOffset.UtcNow;

    public StudyGroupMeeting Meeting { get; set; } = null!;
}

/// <summary>
/// Disponibilités déclarées une fois par l'élève, pour trouver des créneaux communs.
/// Un jour de semaine sans cours est un jour en entreprise : l'élève est pris jusqu'à
/// <see cref="CompanyEndsAt"/>, plus le trajet.
/// </summary>
public sealed class UserAvailability
{
    public static readonly TimeOnly DefaultCompanyEnd = new(17, 30);
    public static readonly TimeOnly DefaultAvailableUntil = new(21, 0);

    public Guid UserId { get; set; }
    public TimeOnly CompanyEndsAt { get; set; } = DefaultCompanyEnd;

    /// <summary>Heure à laquelle une réunion doit être finie, le soir.</summary>
    public TimeOnly AvailableUntil { get; set; } = DefaultAvailableUntil;
    public bool WeekendAvailable { get; set; }
    public bool UsePersonalAgenda { get; set; } = true;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
}
