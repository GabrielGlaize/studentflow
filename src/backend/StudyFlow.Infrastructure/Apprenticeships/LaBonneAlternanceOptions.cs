namespace StudyFlow.Infrastructure.Apprenticeships;

/// <summary>
/// API officielle de La bonne alternance (offres LBA, France Travail et partenaires).
/// Clé gratuite : https://api.apprentissage.beta.gouv.fr/compte/profil
/// </summary>
public sealed class LaBonneAlternanceOptions
{
    public const string SectionName = "LaBonneAlternance";

    public string BaseUrl { get; set; } = "https://api.apprentissage.beta.gouv.fr/api";
    public string? AccessToken { get; set; }
    public int MaxResults { get; set; } = 30;
}
