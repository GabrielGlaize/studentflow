using System.ComponentModel.DataAnnotations;

namespace StudyFlow.Api.Contracts;

public sealed record SubjectRequest(
    [StringLength(120, ErrorMessage = "Matière : 120 caractères maximum.")] string Name,
    [MaxLength(50, ErrorMessage = "50 intervenants maximum par matière.")] IReadOnlyCollection<Guid>? TeacherIds = null);

public sealed record SubjectResponse(Guid Id, string Name, bool IsActive, IReadOnlyCollection<Guid> TeacherIds);

public sealed record TeacherRequest(
    [StringLength(120, ErrorMessage = "Nom de l'intervenant : 120 caractères maximum.")] string DisplayName,
    [StringLength(1000, ErrorMessage = "Informations : 1000 caractères maximum.")] string? Information,
    [MaxLength(50, ErrorMessage = "50 matières maximum par intervenant.")] IReadOnlyCollection<Guid>? SubjectIds = null);

public sealed record TeacherResponse(
    Guid Id,
    string DisplayName,
    string? Information,
    bool IsActive,
    IReadOnlyCollection<Guid> SubjectIds);
