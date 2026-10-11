using StudyFlow.Application.Apprenticeships;

namespace StudyFlow.Infrastructure.Apprenticeships;

/// <summary>Source d'offres qui n'est interrogée que si ses identifiants sont configurés.</summary>
public interface IExternalOpportunitySource : IApprenticeshipOpportunityProvider
{
    bool IsConfigured { get; }
}

/// <summary>Rayon utilisé quand l'élève donne une ville sans préciser de distance.</summary>
internal static class SearchDefaults
{
    public const int DistanceKm = 30;

    public static int DistanceOrDefault(ApprenticeshipOpportunitySearchQuery query) =>
        query.DistanceKm ?? DistanceKm;

    /// <summary>Distance à vol d'oiseau entre le point recherché et l'offre, arrondie à 0,1 km.</summary>
    public static decimal? DistanceKmFrom(ApprenticeshipOpportunitySearchQuery query, decimal? latitude, decimal? longitude)
    {
        if (query.Latitude is null || query.Longitude is null || latitude is null || longitude is null) return null;

        const double earthRadiusKm = 6371;
        static double Radians(decimal degrees) => (double)degrees * Math.PI / 180;
        var deltaLatitude = Radians(latitude.Value - query.Latitude.Value);
        var deltaLongitude = Radians(longitude.Value - query.Longitude.Value);
        var a = Math.Pow(Math.Sin(deltaLatitude / 2), 2)
            + Math.Cos(Radians(query.Latitude.Value)) * Math.Cos(Radians(latitude.Value)) * Math.Pow(Math.Sin(deltaLongitude / 2), 2);
        return Math.Round((decimal)(earthRadiusKm * 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a))), 1);
    }

    /// <summary>Résumé lisible : sans balises HTML, 500 caractères au plus.</summary>
    public static string? CleanSummary(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;

        var withoutTags = System.Text.RegularExpressions.Regex.Replace(value, "<[^>]+>", " ");
        var clean = string.Join(' ', System.Net.WebUtility.HtmlDecode(withoutTags)
            .Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries));
        return clean.Length <= 500 ? clean : $"{clean[..500]}…";
    }
}

/// <summary>Offres fictives, seulement quand aucune source réelle n'est configurée (développement, démo).</summary>
internal static class DemoOpportunities
{
    public static IReadOnlyCollection<ApprenticeshipOpportunity> For(ApprenticeshipOpportunitySearchQuery query) =>
    [
        Demo("demo-1", $"Alternance {query.Keywords}", "Entreprise locale", query, daysAgo: 1),
        Demo("demo-2", $"Apprenti·e {query.Keywords}", "Atelier Numérique", query, daysAgo: 3)
    ];

    private static ApprenticeshipOpportunity Demo(
        string id,
        string title,
        string company,
        ApprenticeshipOpportunitySearchQuery query,
        int daysAgo) =>
        new(
            Source: "demo",
            ExternalId: id,
            OpportunityType: "offer",
            Title: title,
            Company: company,
            Location: query.Location ?? "France",
            DistanceKm: null,
            PublishedAt: DateTimeOffset.UtcNow.AddDays(-daysAgo),
            ExpiresAt: DateTimeOffset.UtcNow.AddDays(30),
            ContractTypes: ["apprentissage"],
            TargetDiploma: null,
            RemoteMode: null,
            Summary: "Offre de démonstration : aucune source d'offres réelle n'est configurée sur ce serveur.",
            ApplicationUrl: "https://labonnealternance.apprentissage.beta.gouv.fr");
}
