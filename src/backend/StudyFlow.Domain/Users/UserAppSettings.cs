using StudyFlow.Domain.Common;

namespace StudyFlow.Domain.Users;

public enum ThemePreference
{
    System = 0,
    Light = 1,
    Dark = 2
}

public enum ProfessionalMode
{
    Apprenticeship = 0,
    Company = 1
}

public sealed class UserAppSettings : Entity
{
    public Guid UserId { get; set; }
    public ThemePreference Theme { get; set; } = ThemePreference.System;
    public bool HasCompany { get; set; }
    public string? CompanyName { get; set; }
    public ProfessionalMode ProfessionalMode { get; set; } = ProfessionalMode.Apprenticeship;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
}
