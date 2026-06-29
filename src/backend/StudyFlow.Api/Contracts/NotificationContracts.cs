namespace StudyFlow.Api.Contracts;

public sealed record NotificationDeviceRequest(
    string Token,
    string Platform);

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
