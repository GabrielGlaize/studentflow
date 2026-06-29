namespace StudyFlow.Api.Contracts;

public sealed record ClassAnnouncementRequest(string Content, bool IsPinned = false);

public sealed record ClassAnnouncementResponse(
    Guid Id,
    string Content,
    bool IsPinned,
    Guid AuthorId,
    string AuthorName,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

public sealed record ApprenticeshipMessageRequest(string Content, string? Link = null);

public sealed record ApprenticeshipMessageResponse(
    Guid Id,
    string Content,
    string? Link,
    Guid AuthorId,
    string AuthorName,
    DateTimeOffset CreatedAt);
