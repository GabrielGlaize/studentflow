using System.ComponentModel.DataAnnotations;

namespace StudyFlow.Api.Contracts;

public sealed record ClassAnnouncementRequest([StringLength(2000, ErrorMessage = "Annonce : 2000 caractères maximum.")] string Content, bool IsPinned = false);

public sealed record ClassAnnouncementResponse(
    Guid Id,
    string Content,
    bool IsPinned,
    Guid AuthorId,
    string AuthorName,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

public sealed record ApprenticeshipMessageRequest(
    [StringLength(1000, ErrorMessage = "Message : 1000 caractères maximum.")] string Content,
    [StringLength(2048, ErrorMessage = "Lien : 2048 caractères maximum.")] string? Link = null);

public sealed record ApprenticeshipMessageResponse(
    Guid Id,
    string Content,
    string? Link,
    Guid AuthorId,
    string AuthorName,
    DateTimeOffset CreatedAt);
