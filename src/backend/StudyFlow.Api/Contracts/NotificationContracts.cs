using System.ComponentModel.DataAnnotations;

namespace StudyFlow.Api.Contracts;

public sealed record NotificationDeviceRequest(
    [StringLength(4096, ErrorMessage = "Jeton de notification : 4096 caractères maximum.")] string Token,
    [StringLength(20, ErrorMessage = "Plateforme : 20 caractères maximum.")] string Platform);

public sealed record NotificationDeviceResponse(
    Guid Id,
    string Platform,
    string TokenPreview,
    DateTimeOffset LastSeenAt);

public sealed record NotificationReminderCandidateResponse(
    string Type,
    Guid UserId,
    Guid RelatedEntityId,
    string Title,
    string Body,
    DateTimeOffset ScheduledAt,
    int DeviceCount);
