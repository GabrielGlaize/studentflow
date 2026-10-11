using Microsoft.Extensions.Logging;
using StudyFlow.Application.Apprenticeships;

namespace StudyFlow.Infrastructure.Apprenticeships;

public sealed class CompositeApprenticeshipOpportunityProvider(
    LaBonneAlternanceOpportunityProvider laBonneAlternanceProvider,
    AdzunaOpportunityProvider adzunaProvider,
    FranceTravailOpportunityProvider franceTravailProvider,
    CityGeocoder geocoder,
    ILogger<CompositeApprenticeshipOpportunityProvider> logger) : IApprenticeshipOpportunityProvider
{
    private const int MaxResults = 40;

    private readonly IExternalOpportunitySource[] _sources =
    [
        laBonneAlternanceProvider,
        adzunaProvider,
        franceTravailProvider
    ];

    public async Task<IReadOnlyCollection<ApprenticeshipOpportunity>> SearchAsync(
        ApprenticeshipOpportunitySearchQuery query,
        CancellationToken cancellationToken = default)
    {
        // Les offres fictives ne se mélangent jamais aux vraies : seulement si aucune source n'est configurée.
        var sources = _sources.Where(source => source.IsConfigured).ToArray();
        if (sources.Length == 0) return DemoOpportunities.For(query);

        var locatedQuery = await LocateAsync(query, cancellationToken);
        var searches = sources.Select(source => SearchSafelyAsync(source, locatedQuery, cancellationToken));
        var providerResults = await Task.WhenAll(searches);

        // Chaque source renvoie ses offres les plus pertinentes d'abord : on les alterne pour garder
        // cet ordre, au lieu de trier par date (une offre récente mais hors sujet passerait devant).
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var merged = new List<ApprenticeshipOpportunity>();
        var longest = providerResults.Length == 0 ? 0 : providerResults.Max(x => x.Count);
        for (var rank = 0; rank < longest && merged.Count < MaxResults; rank++)
        {
            foreach (var results in providerResults)
            {
                var offer = results.ElementAtOrDefault(rank);
                if (offer is not null && seen.Add(DeduplicationKey(offer))) merged.Add(offer);
            }
        }

        return merged.Take(MaxResults).ToArray();
    }

    private async Task<ApprenticeshipOpportunitySearchQuery> LocateAsync(
        ApprenticeshipOpportunitySearchQuery query,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(query.Location)) return query;

        var city = await geocoder.FindAsync(query.Location, cancellationToken);
        if (city is null) return query;

        return query with
        {
            Location = city.Label,
            CityCode = city.CityCode,
            Latitude = query.Latitude ?? city.Latitude,
            Longitude = query.Longitude ?? city.Longitude
        };
    }

    private async Task<IReadOnlyCollection<ApprenticeshipOpportunity>> SearchSafelyAsync(
        IApprenticeshipOpportunityProvider provider,
        ApprenticeshipOpportunitySearchQuery query,
        CancellationToken cancellationToken)
    {
        try
        {
            return await provider.SearchAsync(query, cancellationToken);
        }
        // Le délai d'attente d'HttpClient lève aussi une TaskCanceledException : seule l'annulation
        // demandée par l'appelant doit interrompre la recherche, pas la lenteur d'une source.
        catch (Exception exception) when (!cancellationToken.IsCancellationRequested)
        {
            logger.LogWarning(
                exception,
                "Apprenticeship provider {ProviderName} failed. Other providers will still be used.",
                provider.GetType().Name);
            return [];
        }
    }

    private static string DeduplicationKey(ApprenticeshipOpportunity opportunity)
    {
        // Une même offre relayée par deux sources a un lien différent mais le même intitulé,
        // la même entreprise et le même lieu. Les liens génériques (page d'accueil d'une source)
        // ne doivent pas fusionner des offres distinctes.
        if (!string.IsNullOrWhiteSpace(opportunity.Company))
        {
            return string.Join(
                "|",
                Normalize(opportunity.Title),
                Normalize(opportunity.Company),
                Normalize(opportunity.Location));
        }

        return string.Join("|", opportunity.Source, opportunity.ExternalId);
    }

    private static string Normalize(string? value) =>
        string.Join(' ', (value ?? "").Split(' ', StringSplitOptions.RemoveEmptyEntries)).ToLowerInvariant();
}
