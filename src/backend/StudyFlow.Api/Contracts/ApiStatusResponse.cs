namespace StudyFlow.Api.Contracts;

public sealed record ApiStatusResponse(
    string Service,
    string Status,
    string Version,
    DateTimeOffset Timestamp);
