using System.ComponentModel.DataAnnotations;

namespace StudyFlow.Api.Contracts;

public sealed record HomeworkRequest(
    [StringLength(160, ErrorMessage = "Titre : 160 caractères maximum.")] string Title,
    [StringLength(4000, ErrorMessage = "Description : 4000 caractères maximum.")] string? Description,
    DateTimeOffset Deadline,
    Guid? CourseId = null);

public sealed record HomeworkUpdateRequest(
    [StringLength(160, ErrorMessage = "Titre : 160 caractères maximum.")] string Title,
    [StringLength(4000, ErrorMessage = "Description : 4000 caractères maximum.")] string? Description,
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
    string? SubjectName,
    DateOnly? CourseDay,
    bool IsDone,
    bool NotificationsEnabled,
    DateTimeOffset? CompletedAt,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);
