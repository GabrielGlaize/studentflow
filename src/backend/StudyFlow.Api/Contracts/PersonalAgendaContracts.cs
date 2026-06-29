namespace StudyFlow.Api.Contracts;

public sealed record PersonalTaskRequest(
    string Title,
    string? Description,
    DateTimeOffset? Deadline,
    string Category,
    bool NotificationsEnabled = false,
    Guid? CourseId = null);

public sealed record PersonalTaskUpdateRequest(
    string Title,
    string? Description,
    DateTimeOffset? Deadline,
    string Category,
    bool IsDone,
    bool NotificationsEnabled = false,
    Guid? CourseId = null);

public sealed record PersonalTaskResponse(
    Guid Id,
    string Title,
    string? Description,
    DateTimeOffset? Deadline,
    string Category,
    bool IsDone,
    bool NotificationsEnabled,
    Guid? CourseId,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

public sealed record PersonalEventRequest(
    string Title,
    DateOnly Day,
    TimeOnly StartsAt,
    TimeOnly EndsAt,
    string Category,
    string? Location = null,
    string? Notes = null,
    bool NotificationsEnabled = false);

public sealed record PersonalEventUpdateRequest(
    string Title,
    DateOnly Day,
    TimeOnly StartsAt,
    TimeOnly EndsAt,
    string Category,
    string? Location = null,
    string? Notes = null,
    bool NotificationsEnabled = false);

public sealed record PersonalEventResponse(
    Guid Id,
    string Title,
    DateOnly Day,
    TimeOnly StartsAt,
    TimeOnly EndsAt,
    string Category,
    string? Location,
    string? Notes,
    bool NotificationsEnabled,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);
