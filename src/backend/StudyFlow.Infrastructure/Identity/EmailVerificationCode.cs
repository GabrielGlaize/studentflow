namespace StudyFlow.Infrastructure.Identity;

/// <summary>Code à 6 chiffres envoyé avant la création du compte, lié à une adresse et non à un utilisateur.</summary>
public sealed class EmailVerificationCode
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>Adresse normalisée (majuscules), comme <c>NormalizedEmail</c> d'Identity.</summary>
    public string Email { get; set; } = string.Empty;

    public string CodeHash { get; set; } = string.Empty;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset ExpiresAt { get; set; }
    public DateTimeOffset? UsedAt { get; set; }
    public DateTimeOffset? RevokedAt { get; set; }

    /// <summary>Codes faux tapés : au-delà de la limite, le code est annulé.</summary>
    public int FailedAttempts { get; set; }
}
