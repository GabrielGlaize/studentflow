using StudyFlow.Domain.Common;
using StudyFlow.Domain.School;

namespace StudyFlow.Domain.Exams;

/// <summary>
/// Période de partiels d'une classe. La fiche de révision s'ouvre à toute la classe
/// <see cref="OpensDaysBefore"/> jours avant la première épreuve et se ferme après la dernière.
/// Les délégués la préparent avant l'ouverture.
/// </summary>
public sealed class ExamSession : AuditableEntity
{
    public const int OpensDaysBefore = 14;

    public Guid SchoolClassId { get; set; }
    public string Title { get; set; } = string.Empty;
    public DateOnly StartsOn { get; set; }
    public DateOnly EndsOn { get; set; }
    public Guid CreatedById { get; set; }

    public SchoolClass SchoolClass { get; set; } = null!;
    public ICollection<ExamSubject> Subjects { get; set; } = [];

    public DateOnly OpensOn => StartsOn.AddDays(-OpensDaysBefore);

    public bool IsOpenOn(DateOnly day) => day >= OpensOn && day <= EndsOn;
}
