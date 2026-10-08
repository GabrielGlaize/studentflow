using System.Globalization;
using Microsoft.Extensions.Caching.Memory;
using StudyFlow.Application.Apprenticeships;

namespace StudyFlow.Infrastructure.Apprenticeships;

/// <summary>
/// Cache mémoire des recherches publiques : la même recherche faite par plusieurs visiteurs
/// ne consomme qu'une fois les quotas des API externes (Adzuna, France Travail...).
/// </summary>
public sealed class ApprenticeshipSearchCache : IDisposable
{
    public MemoryCache Entries { get; } = new(new MemoryCacheOptions { SizeLimit = 500 });

    public void Dispose() => Entries.Dispose();
}

public sealed class CachedApprenticeshipOpportunityProvider(
    CompositeApprenticeshipOpportunityProvider innerProvider,
    ApprenticeshipSearchCache cache) : IApprenticeshipOpportunityProvider
{
    private static readonly TimeSpan ResultsLifetime = TimeSpan.FromMinutes(10);

    // Une liste vide vient souvent d'une source indisponible : on la garde peu de temps.
    private static readonly TimeSpan EmptyResultsLifetime = TimeSpan.FromMinutes(1);

    public async Task<IReadOnlyCollection<ApprenticeshipOpportunity>> SearchAsync(
        ApprenticeshipOpportunitySearchQuery query,
        CancellationToken cancellationToken = default)
    {
        var key = CacheKey(query);
        if (cache.Entries.TryGetValue(key, out IReadOnlyCollection<ApprenticeshipOpportunity>? cached) && cached is not null)
        {
            return cached;
        }

        var results = await innerProvider.SearchAsync(query, cancellationToken);
        cache.Entries.Set(key, results, new MemoryCacheEntryOptions
        {
            AbsoluteExpirationRelativeToNow = results.Count == 0 ? EmptyResultsLifetime : ResultsLifetime,
            Size = 1
        });

        return results;
    }

    private static string CacheKey(ApprenticeshipOpportunitySearchQuery query) =>
        string.Join(
            "|",
            query.Keywords.Trim().ToLowerInvariant(),
            query.Location?.Trim().ToLowerInvariant() ?? "",
            query.Latitude?.ToString(CultureInfo.InvariantCulture) ?? "",
            query.Longitude?.ToString(CultureInfo.InvariantCulture) ?? "",
            query.DistanceKm?.ToString(CultureInfo.InvariantCulture) ?? "",
            string.Join(",", query.RomeCodes.Select(x => x.Trim().ToUpperInvariant()).Order()));
}
