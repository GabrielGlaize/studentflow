using System.ComponentModel.DataAnnotations;

namespace StudyFlow.Api.Contracts;

public sealed record ApprenticeshipSearchRequest(
    [StringLength(100, ErrorMessage = "Nom de la recherche : 100 caractères maximum.")] string Name,
    [StringLength(200, ErrorMessage = "Mots-clés : 200 caractères maximum.")] string Keywords,
    [StringLength(200, ErrorMessage = "Lieu : 200 caractères maximum.")] string? Location,
    decimal? Latitude,
    decimal? Longitude,
    int? DistanceKm,
    [StringLength(4000, ErrorMessage = "Filtres : 4000 caractères maximum.")] string FiltersJson = "{}",
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
    [StringLength(80, ErrorMessage = "Source : 80 caractères maximum.")] string Source,
    [StringLength(200, ErrorMessage = "Identifiant de l'offre : 200 caractères maximum.")] string ExternalOfferId,
    [StringLength(250, ErrorMessage = "Titre de l'offre : 250 caractères maximum.")] string Title,
    [StringLength(200, ErrorMessage = "Entreprise : 200 caractères maximum.")] string? Company,
    [StringLength(200, ErrorMessage = "Lieu : 200 caractères maximum.")] string? Location,
    [StringLength(2048, ErrorMessage = "Lien de l'offre : 2048 caractères maximum.")] string Url,
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
    string ApplicationUrl,
    bool IsDemo);
