using StudyFlow.Domain.Common;

namespace StudyFlow.Domain.Exams;

public enum RevisionResourceKind
{
    Link = 0,
    File = 1
}

/// <summary>
/// Ressource partagée pour réviser : un lien (artefact Claude, vidéo, document en ligne)
/// ou un petit fichier d'un type autorisé (PDF, image, page HTML, texte).
/// </summary>
public sealed class RevisionResource : AuditableEntity
{
    public Guid ExamSubjectId { get; set; }
    public Guid AuthorId { get; set; }
    public string Title { get; set; } = string.Empty;
    public RevisionResourceKind Kind { get; set; }
    public string? Url { get; set; }
    public string? FileName { get; set; }

    /// <summary>Type reconnu par le serveur (pdf, image, html, text), jamais celui annoncé par le client.</summary>
    public string? FileType { get; set; }
    public string? ContentType { get; set; }
    public long? SizeBytes { get; set; }

    public ExamSubject ExamSubject { get; set; } = null!;
    public RevisionResourceFile? File { get; set; }
}

/// <summary>Contenu du fichier, dans une table à part pour ne pas le charger avec les listes.</summary>
public sealed class RevisionResourceFile
{
    public Guid RevisionResourceId { get; set; }
    public byte[] Content { get; set; } = [];
}
