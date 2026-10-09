using System.ComponentModel.DataAnnotations;

namespace StudyFlow.Api.Contracts;

public sealed record ExamSessionRequest(
    [StringLength(80, ErrorMessage = "Nom des partiels : 80 caractères maximum.")] string Title,
    DateOnly StartsOn,
    DateOnly EndsOn,
    [MaxLength(20, ErrorMessage = "20 épreuves maximum.")] IReadOnlyCollection<ExamSubjectRequest> Subjects);

public sealed record ExamSubjectRequest(
    Guid SubjectId,
    DateOnly? ExamDay = null,
    TimeOnly? StartsAt = null,
    [StringLength(200, ErrorMessage = "Infos sur l'épreuve : 200 caractères maximum.")] string? Details = null);

/// <param name="IsOpen">La fiche est ouverte à toute la classe (deux semaines avant la première épreuve).</param>
/// <param name="CanContribute">L'utilisateur peut ajouter des points et des ressources.</param>
public sealed record ExamSessionResponse(
    Guid Id,
    string Title,
    DateOnly StartsOn,
    DateOnly EndsOn,
    DateOnly OpensOn,
    bool IsOpen,
    bool CanContribute,
    IReadOnlyCollection<ExamSubjectSummaryResponse> Subjects);

public sealed record ExamSubjectSummaryResponse(
    Guid Id,
    Guid SubjectId,
    string Name,
    DateOnly? ExamDay,
    TimeOnly? StartsAt,
    string? Details,
    int ItemCount,
    int CheckedByMeCount,
    int ResourceCount,
    int ContributorCount);

public sealed record ExamSubjectSheetResponse(
    Guid Id,
    Guid SessionId,
    string SessionTitle,
    Guid SubjectId,
    string Name,
    DateOnly? ExamDay,
    TimeOnly? StartsAt,
    string? Details,
    bool CanContribute,
    IReadOnlyCollection<RevisionItemResponse> Items,
    IReadOnlyCollection<RevisionResourceResponse> Resources);

public sealed record RevisionItemRequest(
    [StringLength(500, ErrorMessage = "Un point à réviser : 500 caractères maximum.")] string Text);

public sealed record RevisionCheckRequest(bool Checked);

public sealed record RevisionItemResponse(
    Guid Id,
    string Text,
    string AuthorName,
    bool IsMine,
    bool CanEdit,
    bool CheckedByMe,
    int CheckCount,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

public sealed record RevisionLinkRequest(
    [StringLength(2000, ErrorMessage = "Ce lien est trop long.")] string Url,
    [StringLength(120, ErrorMessage = "Titre : 120 caractères maximum.")] string? Title = null);

/// <param name="Kind">« link » ou « file ».</param>
/// <param name="FileType">Pour un fichier : pdf, image, html ou text.</param>
public sealed record RevisionResourceResponse(
    Guid Id,
    string Kind,
    string Title,
    string? Url,
    string? FileName,
    string? FileType,
    long? SizeBytes,
    string AuthorName,
    bool IsMine,
    bool CanEdit,
    DateTimeOffset CreatedAt);
