namespace StudyFlow.Domain.School;

/// <summary>
/// Lien entre une matière et un intervenant : une matière peut avoir plusieurs intervenants
/// et un intervenant peut enseigner plusieurs matières.
/// </summary>
public sealed class SubjectTeacher
{
    public Guid SubjectId { get; set; }
    public Guid TeacherId { get; set; }

    public Subject Subject { get; set; } = null!;
    public Teacher Teacher { get; set; } = null!;
}
