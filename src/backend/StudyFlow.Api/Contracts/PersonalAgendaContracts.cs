using System.ComponentModel.DataAnnotations;

namespace StudyFlow.Api.Contracts;

public sealed record PersonalTaskRequest(
    [StringLength(160, ErrorMessage = "Titre : 160 caractères maximum.")] string Title,
    [StringLength(4000, ErrorMessage = "Description : 4000 caractères maximum.")] string? Description,
    DateTimeOffset? Deadline,
    [StringLength(20, ErrorMessage = "Catégorie : 20 caractères maximum.")] string Category,
    bool NotificationsEnabled = false,
    Guid? CourseId = null);

public sealed record PersonalTaskUpdateRequest(
    [StringLength(160, ErrorMessage = "Titre : 160 caractères maximum.")] string Title,
    [StringLength(4000, ErrorMessage = "Description : 4000 caractères maximum.")] string? Description,
    DateTimeOffset? Deadline,
    [StringLength(20, ErrorMessage = "Catégorie : 20 caractères maximum.")] string Category,
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
    [StringLength(160, ErrorMessage = "Titre : 160 caractères maximum.")] string Title,
    DateOnly Day,
    TimeOnly StartsAt,
    TimeOnly EndsAt,
    [StringLength(20, ErrorMessage = "Catégorie : 20 caractères maximum.")] string Category,
    [StringLength(200, ErrorMessage = "Lieu : 200 caractères maximum.")] string? Location = null,
    [StringLength(2000, ErrorMessage = "Notes : 2000 caractères maximum.")] string? Notes = null,
    bool NotificationsEnabled = false);

public sealed record PersonalEventUpdateRequest(
    [StringLength(160, ErrorMessage = "Titre : 160 caractères maximum.")] string Title,
    DateOnly Day,
    TimeOnly StartsAt,
    TimeOnly EndsAt,
    [StringLength(20, ErrorMessage = "Catégorie : 20 caractères maximum.")] string Category,
    [StringLength(200, ErrorMessage = "Lieu : 200 caractères maximum.")] string? Location = null,
    [StringLength(2000, ErrorMessage = "Notes : 2000 caractères maximum.")] string? Notes = null,
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
