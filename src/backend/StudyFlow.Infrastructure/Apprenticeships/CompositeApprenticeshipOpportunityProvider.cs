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
        catch (Exception exception) when (exception is not OperationCanceledException)
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
        if (!string.IsNullOrWhiteSpace(opportunity.ApplicationUrl))
        {
            return opportunity.ApplicationUrl.Trim();
        }

        return string.Join(
            "|",
            opportunity.Source,
            opportunity.ExternalId,
            opportunity.Title,
            opportunity.Company,
            opportunity.Location);
    }
}
