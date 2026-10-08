namespace StudyFlow.Application.Apprenticeships;

public sealed record ApprenticeshipOpportunitySearchQuery(
    string Keywords,
    string? Location,
    decimal? Latitude,
    decimal? Longitude,
    int? DistanceKm,
    IReadOnlyCollection<string> RomeCodes);

public sealed record ApprenticeshipOpportunity(
    string Source,
    string ExternalId,
    string OpportunityType,
    string Title,
    string? Company,
    string? Location,
    decimal? DistanceKm,
    DateTimeOffset? PublishedAt,
    DateTimeOffset? ExpiresAt,
    IReadOnlyCollection<string> ContractTypes,
    string? TargetDiploma,
    string? RemoteMode,
    string? Summary,
    string ApplicationUrl)
{
    /// <summary>Offre fictive affichée quand aucune source externe n'est configurée.</summary>
    public bool IsDemo => Source.StartsWith("demo", StringComparison.OrdinalIgnoreCase);
}

public interface IApprenticeshipOpportunityProvider
{
    Task<IReadOnlyCollection<ApprenticeshipOpportunity>> SearchAsync(
        ApprenticeshipOpportunitySearchQuery query,
        CancellationToken cancellationToken = default);
}
