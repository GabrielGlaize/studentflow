using StudyFlow.Domain.Common;
using StudyFlow.Domain.School;

namespace StudyFlow.Domain.Groups;

/// <summary>
/// Groupe de travail privé entre élèves d'une même classe. Il peut être rattaché à un devoir
/// (qui lui donne sa date de rendu) et à un cours de la classe. Seuls ses membres voient
/// son contenu ; la description et tout ce qui est écrit dedans est chiffré en base.
/// </summary>
public sealed class StudyGroup : AuditableEntity
{
    public const int MaxMembers = 8;

    /// <summary>Après la date de rendu, le groupe reste consultable mais passe dans les archives.</summary>
    public static readonly TimeSpan ArchiveDelay = TimeSpan.FromDays(7);

    public Guid SchoolClassId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? EncryptedDescription { get; set; }
    public Guid? SubjectId { get; set; }
    public Guid? HomeworkId { get; set; }

    /// <summary>Date de rendu saisie à la main, utilisée quand aucun devoir n'est rattaché.</summary>
    public DateTimeOffset? DueAt { get; set; }
    public Guid? CreatedById { get; set; }

    public SchoolClass SchoolClass { get; set; } = null!;
    public Subject? Subject { get; set; }
    public Homework? Homework { get; set; }
    public ICollection<StudyGroupMember> Members { get; set; } = [];
    public ICollection<StudyGroupTask> Tasks { get; set; } = [];

    /// <summary>Le devoir rattaché fait foi pour la date de rendu.</summary>
    public DateTimeOffset? EffectiveDueAt =>
        Homework is { DeletedAt: null } homework ? homework.Deadline : DueAt;

    public bool IsArchivedAt(DateTimeOffset now) =>
        EffectiveDueAt is { } dueAt && dueAt + ArchiveDelay < now;
}

public enum StudyGroupRole
{
    Member = 0,
    Organizer = 1
}

public enum StudyGroupMemberStatus
{
    Invited = 0,
    Active = 1
}

public sealed class StudyGroupMember
{
    public Guid StudyGroupId { get; set; }
    public Guid UserId { get; set; }
    public StudyGroupRole Role { get; set; }
    public StudyGroupMemberStatus Status { get; set; }

    /// <summary>Rôle libre choisi par l'élève : « Rédaction », « Diapos », « Partie SQL »…</summary>
    public string? RoleLabel { get; set; }
    public Guid? InvitedById { get; set; }
    public DateTimeOffset InvitedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? JoinedAt { get; set; }

    /// <summary>Dernier message lu : sert au compteur de non-lus et au « vu ».</summary>
    public DateTimeOffset? LastReadAt { get; set; }

    public StudyGroup Group { get; set; } = null!;
}
