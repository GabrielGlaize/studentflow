namespace StudyFlow.Infrastructure.Apprenticeships;

public sealed class AdzunaOptions
{
    public const string SectionName = "Adzuna";

    public string? BaseUrl { get; set; } = "https://api.adzuna.com";
    public string Country { get; set; } = "fr";
    public string? AppId { get; set; }
    public string? AppKey { get; set; }
    public int ResultsPerPage { get; set; } = 10;
    public bool UseDemoWhenNotConfigured { get; set; } = true;
}
