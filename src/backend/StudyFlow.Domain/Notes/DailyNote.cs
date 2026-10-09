using StudyFlow.Domain.Common;

namespace StudyFlow.Domain.Notes;

/// <summary>
/// Note libre d'une journée, strictement personnelle. Le texte est chiffré en base :
/// seul son auteur le relit, à travers l'API.
/// </summary>
public sealed class DailyNote : Entity
{
    public Guid UserId { get; set; }
    public DateOnly Day { get; set; }
    public string EncryptedText { get; set; } = string.Empty;

    /// <summary>Dernière modification côté app : la plus récente l'emporte entre appareils.</summary>
    public DateTimeOffset UpdatedAt { get; set; }

    /// <summary>Relue le soir : l'accueil arrête de la mettre en avant.</summary>
    public DateTimeOffset? ReviewedAt { get; set; }
}
