using System.ComponentModel.DataAnnotations;

namespace StudyFlow.Api.Contracts;

/// <param name="Text">Texte complet de la note ; vide pour la supprimer.</param>
/// <param name="UpdatedAt">Moment de la modification sur l'appareil.</param>
public sealed record DailyNoteRequest(
    [StringLength(20000, ErrorMessage = "Note : 20 000 caractères maximum.")] string? Text,
    DateTimeOffset UpdatedAt,
    DateTimeOffset? ReviewedAt = null);

public sealed record DailyNoteResponse(
    DateOnly Day,
    string Text,
    DateTimeOffset UpdatedAt,
    DateTimeOffset? ReviewedAt);
