namespace StudyFlow.Api.Contracts;

public sealed record CourseRequest(
    Guid SubjectId,
    Guid? TeacherId,
    DateOnly Day,
    TimeOnly StartsAt,
    TimeOnly EndsAt,
    string Room,
    bool IsCancelled = false,
    Guid? SeriesId = null);

public sealed record CourseUpdateRequest(
    Guid SubjectId,
    Guid? TeacherId,
    DateOnly Day,
    TimeOnly StartsAt,
    TimeOnly EndsAt,
    string Room,
    bool IsCancelled,
    long Version,
    Guid? SeriesId = null);

public sealed record CourseResponse(
    Guid Id,
    Guid SubjectId,
    string SubjectName,
    Guid? TeacherId,
    string? TeacherName,
    DateOnly Day,
    TimeOnly StartsAt,
    TimeOnly EndsAt,
    string Room,
    bool IsCancelled,
    long Version);

public sealed record CourseRevisionResponse(
    Guid Id,
    string Action,
    string AuthorName,
    DateTimeOffset CreatedAt,
    long Version);
