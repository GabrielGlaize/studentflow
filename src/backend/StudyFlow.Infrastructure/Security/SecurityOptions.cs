namespace StudyFlow.Infrastructure.Security;

public sealed class SecurityOptions
{
    public const string SectionName = "Security";

    public string LookupKey { get; set; } = string.Empty;
    public string? DataProtectionKeysPath { get; set; }
    public int PasswordResetTokenMinutes { get; set; } = 30;
}
