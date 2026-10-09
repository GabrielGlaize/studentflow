using StudyFlow.Domain.Common;
using StudyFlow.Domain.School;

namespace StudyFlow.Domain.Exams;

/// <summary>Une épreuve des partiels, rattachée à une matière de la classe.</summary>
public sealed class ExamSubject : Entity
{
    public Guid ExamSessionId { get; set; }
    public Guid SubjectId { get; set; }
    public DateOnly? ExamDay { get; set; }
    public TimeOnly? StartsAt { get; set; }

    /// <summary>Format de l'épreuve, documents autorisés, durée…</summary>
    public string? Details { get; set; }

    public int Position { get; set; }

    public ExamSession Session { get; set; } = null!;
    public Subject Subject { get; set; } = null!;
    public ICollection<RevisionItem> Items { get; set; } = [];
    public ICollection<RevisionResource> Resources { get; set; } = [];
}
