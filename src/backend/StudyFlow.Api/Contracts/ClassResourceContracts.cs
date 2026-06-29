namespace StudyFlow.Api.Contracts;

public sealed record SubjectRequest(string Name);
public sealed record SubjectResponse(Guid Id, string Name, bool IsActive);

public sealed record TeacherRequest(string DisplayName, string? Information);
public sealed record TeacherResponse(Guid Id, string DisplayName, string? Information, bool IsActive);
