namespace StudyFlow.Application.Security;

public enum EmailVerificationRequestStatus
{
    Sent,
    AlreadyRegistered,
    TooSoon,
    EmailUnavailable
}

public sealed record EmailVerificationRequestResult(
    EmailVerificationRequestStatus Status,
    string? DevelopmentCode = null,
    DateTimeOffset? ExpiresAt = null);

/// <summary>
/// Code envoyé à l'adresse saisie à l'inscription : le compte n'est créé qu'avec ce code,
/// ce qui prouve que l'élève possède bien l'adresse.
/// </summary>
public interface IEmailVerificationService
{
    /// <summary>Faux en développement local ou dans certains tests : l'inscription n'exige pas de code.</summary>
    bool IsRequired { get; }

    Task<EmailVerificationRequestResult> RequestCodeAsync(
        string email,
        CancellationToken cancellationToken = default);

    /// <summary>Vérifie le code sans le consommer ; chaque erreur compte pour le blocage.</summary>
    Task<bool> CheckCodeAsync(
        string email,
        string? code,
        CancellationToken cancellationToken = default);

    /// <summary>Marque le code comme utilisé, une fois le compte créé (sauvegarde par l'appelant).</summary>
    Task ConsumeCodeAsync(
        string email,
        CancellationToken cancellationToken = default);
}

public interface IEmailVerificationSender
{
    /// <returns>Faux si aucun e-mail ne peut partir (SMTP non configuré hors développement).</returns>
    Task<bool> SendEmailVerificationAsync(
        string email,
        string code,
        DateTimeOffset expiresAt,
        CancellationToken cancellationToken = default);
}
