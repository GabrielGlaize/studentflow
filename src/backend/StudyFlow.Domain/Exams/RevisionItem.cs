using StudyFlow.Domain.Common;

namespace StudyFlow.Domain.Exams;

/// <summary>Un point à réviser, ajouté par n'importe quel élève de la classe.</summary>
public sealed class RevisionItem : AuditableEntity
{
    public Guid ExamSubjectId { get; set; }
    public Guid AuthorId { get; set; }
    public string Text { get; set; } = string.Empty;

    public ExamSubject ExamSubject { get; set; } = null!;
    public ICollection<RevisionItemCheck> Checks { get; set; } = [];
}

/// <summary>Un élève a coché ce point comme révisé (case personnelle).</summary>
public sealed class RevisionItemCheck
{
    public Guid RevisionItemId { get; set; }
    public Guid UserId { get; set; }
    public DateTimeOffset CheckedAt { get; set; } = DateTimeOffset.UtcNow;

    public RevisionItem Item { get; set; } = null!;
}
