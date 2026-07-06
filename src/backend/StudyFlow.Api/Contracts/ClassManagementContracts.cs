namespace StudyFlow.Api.Contracts;

public sealed record CurrentClassResponse(
    Guid Id,
    string Name,
    string SchoolYear,
    bool IsDelegate,
    string? AccessCode,
    DateTimeOffset AccessCodeUpdatedAt);

public sealed record UpdateClassRequest(string Name, string SchoolYear);

public sealed record ClassAccessCodeResponse(string AccessCode, DateTimeOffset UpdatedAt);

public sealed record ClassMemberResponse(
    Guid Id,
    string FirstName,
    string LastName,
    string Email,
    bool IsDelegate);
