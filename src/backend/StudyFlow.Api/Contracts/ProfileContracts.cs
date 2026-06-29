namespace StudyFlow.Api.Contracts;

public sealed record ProfileResponse(
    Guid Id,
    string Email,
    string FirstName,
    string LastName,
    Guid? SchoolClassId,
    IReadOnlyCollection<string> Roles,
    AppSettingsResponse AppSettings,
    NotificationSettingsResponse NotificationSettings);

public sealed record UpdateProfileRequest(string FirstName, string LastName);

public sealed record AppSettingsRequest(
    string Theme,
    bool HasCompany,
    string? CompanyName,
    string ProfessionalMode);

public sealed record AppSettingsResponse(
    string Theme,
    bool HasCompany,
    string? CompanyName,
    string ProfessionalMode);

public sealed record NotificationSettingsRequest(
    bool CoursesEnabled,
    bool HomeworkEnabled,
    bool ApprenticeshipsEnabled,
    int CourseReminderMinutes);

public sealed record NotificationSettingsResponse(
    bool CoursesEnabled,
    bool HomeworkEnabled,
    bool ApprenticeshipsEnabled,
    int CourseReminderMinutes);
