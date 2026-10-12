using StudyFlow.Domain.Common;

namespace StudyFlow.Domain.Groups;

public enum StudyGroupTaskStatus
{
    Todo = 0,
    Doing = 1,
    Done = 2
}

/// <summary>Tâche du groupe, affectée à un ou plusieurs membres. Titre et notes chiffrés.</summary>
public sealed class StudyGroupTask : AuditableEntity
{
    public Guid StudyGroupId { get; set; }
    public string EncryptedTitle { get; set; } = string.Empty;
    public string? EncryptedNotes { get; set; }
    public StudyGroupTaskStatus Status { get; set; }
    public DateOnly? DueOn { get; set; }
    public Guid? CreatedById { get; set; }
    public DateTimeOffset? CompletedAt { get; set; }

    public StudyGroup Group { get; set; } = null!;
    public ICollection<StudyGroupTaskAssignee> Assignees { get; set; } = [];
}

public sealed class StudyGroupTaskAssignee
{
    public Guid StudyGroupTaskId { get; set; }
    public Guid UserId { get; set; }

    public StudyGroupTask Task { get; set; } = null!;
}

/// <summary>
/// Message de la discussion du groupe. Sans auteur, c'est un message du système
/// (« Léa a rejoint le groupe »). Le texte est chiffré en base.
/// </summary>
public sealed class StudyGroupMessage : Entity
{
    public Guid StudyGroupId { get; set; }
    public Guid? AuthorId { get; set; }
    public string EncryptedText { get; set; } = string.Empty;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? DeletedAt { get; set; }

    public StudyGroup Group { get; set; } = null!;
}

public enum StudyGroupResourceKind
{
    Link = 0,
    File = 1
}

/// <summary>Lien ou petit fichier partagé dans le groupe. Titre, lien et contenu sont chiffrés.</summary>
public sealed class StudyGroupResource : AuditableEntity
{
    public Guid StudyGroupId { get; set; }
    public Guid? AuthorId { get; set; }
    public StudyGroupResourceKind Kind { get; set; }
    public string EncryptedTitle { get; set; } = string.Empty;
    public string? EncryptedUrl { get; set; }
    public string? FileName { get; set; }
    public string? FileType { get; set; }
    public string? ContentType { get; set; }
    public long? SizeBytes { get; set; }

    public StudyGroup Group { get; set; } = null!;
    public StudyGroupResourceFile? File { get; set; }
}

public sealed class StudyGroupResourceFile
{
    public Guid StudyGroupResourceId { get; set; }

    /// <summary>Contenu chiffré (Data Protection), relu seulement par l'API.</summary>
    public byte[] EncryptedContent { get; set; } = [];
}
