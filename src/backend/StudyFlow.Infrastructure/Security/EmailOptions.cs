namespace StudyFlow.Infrastructure.Security;

public sealed class EmailOptions
{
    public const string SectionName = "Email";

    public string From { get; set; } = "";
    public string Host { get; set; } = "";
    public int Port { get; set; } = 587;
    public bool UseSsl { get; set; } = true;
    public string UserName { get; set; } = "";
    public string Password { get; set; } = "";
    public string PasswordResetUrlBase { get; set; } = "";

    /// <summary>Adresse qui reçoit les idées et bugs ; vide = celle du compte d'envoi.</summary>
    public string FeedbackTo { get; set; } = "";

    public bool IsSmtpConfigured =>
        !string.IsNullOrWhiteSpace(From)
        && !string.IsNullOrWhiteSpace(Host);
}
