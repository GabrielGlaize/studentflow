using Microsoft.Extensions.Logging;
using StudyFlow.Application.Apprenticeships;

namespace StudyFlow.Infrastructure.Apprenticeships;

public sealed class CompositeApprenticeshipOpportunityProvider(
    LaBonneAlternanceOpportunityProvider laBonneAlternanceProvider,
    AdzunaOpportunityProvider adzunaProvider,
    FranceTravailOpportunityProvider franceTravailProvider,
    ILogger<CompositeApprenticeshipOpportunityProvider> logger) : IApprenticeshipOpportunityProvider
{
    private readonly IApprenticeshipOpportunityProvider[] _providers =
    [
        laBonneAlternanceProvider,
        adzunaProvider,
        franceTravailProvider
    ];

    public async Task<IReadOnlyCollection<ApprenticeshipOpportunity>> SearchAsync(
        ApprenticeshipOpportunitySearchQuery query,
        CancellationToken cancellationToken = default)
    {
        var searches = _providers.Select(provider => SearchSafelyAsync(provider, query, cancellationToken));
        var providerResults = await Task.WhenAll(searches);

        return providerResults
            .SelectMany(x => x)
            .GroupBy(DeduplicationKey, StringComparer.OrdinalIgnoreCase)
            .Select(group => group.OrderByDescending(x => x.PublishedAt ?? DateTimeOffset.MinValue).First())
            .OrderByDescending(x => x.PublishedAt ?? DateTimeOffset.MinValue)
            .Take(30)
            .ToArray();
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
