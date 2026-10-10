namespace StudyFlow.Infrastructure.Identity;

public sealed class PasswordResetToken
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public string TokenHash { get; set; } = string.Empty;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset ExpiresAt { get; set; }
    public DateTimeOffset? UsedAt { get; set; }
    public DateTimeOffset? RevokedAt { get; set; }
    public string? RequestIpHash { get; set; }

    /// <summary>Codes faux tapés : au-delà de la limite, le code est annulé.</summary>
    public int FailedAttempts { get; set; }

    public ApplicationUser User { get; set; } = null!;
}
