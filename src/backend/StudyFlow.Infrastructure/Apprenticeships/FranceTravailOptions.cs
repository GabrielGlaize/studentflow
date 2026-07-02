namespace StudyFlow.Infrastructure.Apprenticeships;

public sealed class FranceTravailOptions
{
    public const string SectionName = "FranceTravail";

    public string? TokenUrl { get; set; } = "https://entreprise.francetravail.fr/connexion/oauth2/access_token";
    public string Realm { get; set; } = "/partenaire";
    public string? SearchUrl { get; set; } = "https://api.francetravail.io/partenaire/offresdemploi/v2/offres/search";
    public string? ClientId { get; set; }
    public string? ClientSecret { get; set; }
    public string Scope { get; set; } = "api_offresdemploiv2 o2dsoffre";
    public int ResultsPerPage { get; set; } = 10;
    public bool UseDemoWhenNotConfigured { get; set; } = false;
}
