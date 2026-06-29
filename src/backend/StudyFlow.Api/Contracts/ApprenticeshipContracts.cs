namespace StudyFlow.Api.Contracts;

public sealed record ApprenticeshipSearchRequest(
    string Name,
    string Keywords,
    string? Location,
    decimal? Latitude,
    decimal? Longitude,
    int? DistanceKm,
    string FiltersJson = "{}",
    bool AlertEnabled = false);

public sealed record ApprenticeshipSearchResponse(
    Guid Id,
    string Name,
    string Keywords,
    string? Location,
    decimal? Latitude,
    decimal? Longitude,
    int? DistanceKm,
    string FiltersJson,
    bool AlertEnabled,
    DateTimeOffset? LastCheckedAt,
    DateTimeOffset CreatedAt);

public sealed record FavoriteOfferRequest(
    string Source,
    string ExternalOfferId,
    string Title,
    string? Company,
    string? Location,
    string Url,
    DateTimeOffset? PublishedAt = null);

public sealed record FavoriteOfferResponse(
    Guid Id,
    string Source,
    string ExternalOfferId,
    string Title,
    string? Company,
    string? Location,
    string Url,
    DateTimeOffset? PublishedAt,
    DateTimeOffset SavedAt);

public sealed record ApprenticeshipOpportunityResponse(
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
    string ApplicationUrl);
