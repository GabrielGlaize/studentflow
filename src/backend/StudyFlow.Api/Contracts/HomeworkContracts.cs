namespace StudyFlow.Api.Contracts;

public sealed record HomeworkRequest(
    string Title,
    string? Description,
    DateTimeOffset Deadline,
    Guid? CourseId = null);

public sealed record HomeworkUpdateRequest(
    string Title,
    string? Description,
    DateTimeOffset Deadline,
    Guid? CourseId = null);

public sealed record HomeworkProgressRequest(
    bool IsDone,
    bool NotificationsEnabled = true);

public sealed record HomeworkResponse(
    Guid Id,
    string Title,
    string? Description,
    DateTimeOffset Deadline,
    Guid? CourseId,
    bool IsDone,
    bool NotificationsEnabled,
    DateTimeOffset? CompletedAt,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);
