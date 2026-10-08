using System.ComponentModel.DataAnnotations;

namespace StudyFlow.Api.Contracts;

public sealed record SubjectRequest([StringLength(120, ErrorMessage = "Matière : 120 caractères maximum.")] string Name);
public sealed record SubjectResponse(Guid Id, string Name, bool IsActive);

public sealed record TeacherRequest(
    [StringLength(120, ErrorMessage = "Nom du professeur : 120 caractères maximum.")] string DisplayName,
    [StringLength(1000, ErrorMessage = "Informations : 1000 caractères maximum.")] string? Information);
public sealed record TeacherResponse(Guid Id, string DisplayName, string? Information, bool IsActive);
