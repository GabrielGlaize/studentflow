using System.ComponentModel.DataAnnotations;

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

public sealed record UpdateProfileRequest([StringLength(80, ErrorMessage = "Prénom : 80 caractères maximum.")] string FirstName, [StringLength(80, ErrorMessage = "Nom : 80 caractères maximum.")] string LastName);

public sealed record AppSettingsRequest(
    [StringLength(20, ErrorMessage = "Thème : 20 caractères maximum.")] string Theme,
    bool HasCompany,
    [StringLength(160, ErrorMessage = "Nom de l'entreprise : 160 caractères maximum.")] string? CompanyName,
    [StringLength(30, ErrorMessage = "Mode professionnel : 30 caractères maximum.")] string ProfessionalMode);

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
