namespace StudyFlow.Infrastructure.Apprenticeships;

public sealed class LaBonneAlternanceOptions
{
    public const string SectionName = "LaBonneAlternance";

    public string? BaseUrl { get; set; }
    public string SearchPath { get; set; } = "/fr/explorer/recherche-offre";
    public string? AccessToken { get; set; }
    public bool UseDemoWhenNotConfigured { get; set; } = true;
}
