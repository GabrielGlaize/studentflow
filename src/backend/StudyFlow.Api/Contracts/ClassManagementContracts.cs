using System.ComponentModel.DataAnnotations;

namespace StudyFlow.Api.Contracts;

public sealed record CurrentClassResponse(
    Guid Id,
    string Name,
    string SchoolYear,
    bool IsDelegate,
    string? AccessCode,
    DateTimeOffset AccessCodeUpdatedAt);

public sealed record UpdateClassRequest(
    [StringLength(80, ErrorMessage = "Nom de la classe : 80 caractères maximum.")] string Name,
    [StringLength(9, ErrorMessage = "L'année scolaire doit être au format 2026-2027.")] string SchoolYear);

public sealed record ClassAccessCodeResponse(string AccessCode, DateTimeOffset UpdatedAt);

public sealed record ClassMemberResponse(
    Guid Id,
    string FirstName,
    string LastName,
    string? Email,
    bool IsDelegate);
