namespace StudyFlow.Infrastructure.Security;

public sealed class SecurityOptions
{
    public const string SectionName = "Security";

    public string LookupKey { get; set; } = string.Empty;
    public string? DataProtectionKeysPath { get; set; }
    public int PasswordResetTokenMinutes { get; set; } = 30;
    public int EmailVerificationCodeMinutes { get; set; } = 15;

    /// <summary>L'inscription exige le code reçu par e-mail. Désactivable pour les tests et la démo locale.</summary>
    public bool RequireEmailVerification { get; set; } = true;
}
