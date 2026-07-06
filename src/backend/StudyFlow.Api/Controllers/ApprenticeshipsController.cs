using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StudyFlow.Api.Contracts;
using StudyFlow.Application.Apprenticeships;
using StudyFlow.Domain.Apprenticeships;
using StudyFlow.Infrastructure.Identity;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/apprenticeships")]
public sealed class ApprenticeshipsController(
    UserManager<ApplicationUser> userManager,
    StudyFlowDbContext dbContext,
    IApprenticeshipOpportunityProvider opportunityProvider) : ControllerBase
{
    [AllowAnonymous]
    [HttpGet("opportunities")]
    [HttpGet("/api/v1/public/alternances")]
    public async Task<ActionResult<IReadOnlyCollection<ApprenticeshipOpportunityResponse>>> SearchOpportunities(
        [FromQuery] string keywords,
        [FromQuery] string? location,
        [FromQuery] decimal? latitude,
        [FromQuery] decimal? longitude,
        [FromQuery] int? distanceKm,
        [FromQuery] string[]? romeCodes,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(keywords)) return BadRequestProblem("Les mots-cles sont obligatoires.");
        if (distanceKm is < 0) return BadRequestProblem("La distance ne peut pas etre negative.");

        var query = new ApprenticeshipOpportunitySearchQuery(
            keywords.Trim(),
            CleanOptional(location),
            latitude,
            longitude,
            distanceKm,
            romeCodes?.Where(x => !string.IsNullOrWhiteSpace(x)).Select(x => x.Trim()).ToArray() ?? []);

        var results = await opportunityProvider.SearchAsync(query, cancellationToken);
        return Ok(results.Select(ToOpportunityResponse).ToArray());
    }

    [HttpGet("saved-searches")]
    public async Task<ActionResult<IReadOnlyCollection<ApprenticeshipSearchResponse>>> ListSavedSearches(
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();

        var searches = await dbContext.ApprenticeshipSearches
            .AsNoTracking()
            .Where(x => x.UserId == user.Id)
            .OrderByDescending(x => x.CreatedAt)
            .ToListAsync(cancellationToken);

        return Ok(searches.Select(ToSearchResponse).ToArray());
    }

    [HttpPost("saved-searches")]
    public async Task<ActionResult<ApprenticeshipSearchResponse>> CreateSavedSearch(
        ApprenticeshipSearchRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();

        var validationProblem = ValidateSearchRequest(request);
        if (validationProblem is not null) return validationProblem;

        var search = new ApprenticeshipSearch
        {
            UserId = user.Id,
            Name = request.Name.Trim(),
            Keywords = request.Keywords.Trim(),
            Location = CleanOptional(request.Location),
            Latitude = request.Latitude,
            Longitude = request.Longitude,
            DistanceKm = request.DistanceKm,
            FiltersJson = NormalizeJson(request.FiltersJson),
            AlertEnabled = request.AlertEnabled
        };

        dbContext.ApprenticeshipSearches.Add(search);
        await dbContext.SaveChangesAsync(cancellationToken);

        return CreatedAtAction(nameof(ListSavedSearches), ToSearchResponse(search));
    }

    [HttpPut("saved-searches/{id:guid}")]
    public async Task<ActionResult<ApprenticeshipSearchResponse>> UpdateSavedSearch(
        Guid id,
        ApprenticeshipSearchRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();

        var search = await dbContext.ApprenticeshipSearches
            .SingleOrDefaultAsync(x => x.Id == id && x.UserId == user.Id, cancellationToken);
        if (search is null) return NotFound();

        var validationProblem = ValidateSearchRequest(request);
        if (validationProblem is not null) return validationProblem;

        search.Name = request.Name.Trim();
        search.Keywords = request.Keywords.Trim();
        search.Location = CleanOptional(request.Location);
        search.Latitude = request.Latitude;
        search.Longitude = request.Longitude;
        search.DistanceKm = request.DistanceKm;
        search.FiltersJson = NormalizeJson(request.FiltersJson);
        search.AlertEnabled = request.AlertEnabled;

        await dbContext.SaveChangesAsync(cancellationToken);
        return Ok(ToSearchResponse(search));
    }

    [HttpDelete("saved-searches/{id:guid}")]
    public async Task<IActionResult> DeleteSavedSearch(Guid id, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();

        var search = await dbContext.ApprenticeshipSearches
            .SingleOrDefaultAsync(x => x.Id == id && x.UserId == user.Id, cancellationToken);
        if (search is null) return NotFound();

        dbContext.ApprenticeshipSearches.Remove(search);
        await dbContext.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    [HttpGet("favorite-offers")]
    public async Task<ActionResult<IReadOnlyCollection<FavoriteOfferResponse>>> ListFavoriteOffers(
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();

        var offers = await dbContext.FavoriteOffers
            .AsNoTracking()
            .Where(x => x.UserId == user.Id)
            .OrderByDescending(x => x.SavedAt)
            .ToListAsync(cancellationToken);

        return Ok(offers.Select(ToFavoriteResponse).ToArray());
    }

    [HttpPost("favorite-offers")]
    public async Task<ActionResult<FavoriteOfferResponse>> SaveFavoriteOffer(
        FavoriteOfferRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();

        var validationProblem = ValidateFavoriteRequest(request);
        if (validationProblem is not null) return validationProblem;

        var source = request.Source.Trim();
        var externalOfferId = request.ExternalOfferId.Trim();
        var existing = await dbContext.FavoriteOffers.SingleOrDefaultAsync(
            x => x.UserId == user.Id && x.Source == source && x.ExternalOfferId == externalOfferId,
            cancellationToken);

        if (existing is not null)
        {
            return Ok(ToFavoriteResponse(existing));
        }

        var offer = new FavoriteOffer
        {
            UserId = user.Id,
            Source = source,
            ExternalOfferId = externalOfferId,
            Title = request.Title.Trim(),
            Company = CleanOptional(request.Company),
            Location = CleanOptional(request.Location),
            Url = request.Url.Trim(),
            PublishedAt = request.PublishedAt
        };

        dbContext.FavoriteOffers.Add(offer);
        await dbContext.SaveChangesAsync(cancellationToken);

        return CreatedAtAction(nameof(ListFavoriteOffers), ToFavoriteResponse(offer));
    }

    [HttpDelete("favorite-offers/{id:guid}")]
    public async Task<IActionResult> DeleteFavoriteOffer(Guid id, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();

        var offer = await dbContext.FavoriteOffers
            .SingleOrDefaultAsync(x => x.Id == id && x.UserId == user.Id, cancellationToken);
        if (offer is null) return NotFound();

        dbContext.FavoriteOffers.Remove(offer);
        await dbContext.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    private ActionResult? ValidateSearchRequest(ApprenticeshipSearchRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Name)) return BadRequestProblem("Le nom de la recherche est obligatoire.");
        if (string.IsNullOrWhiteSpace(request.Keywords)) return BadRequestProblem("Les mots-cles sont obligatoires.");
        if (request.DistanceKm is < 0) return BadRequestProblem("La distance ne peut pas etre negative.");

        try
        {
            _ = JsonDocument.Parse(NormalizeJson(request.FiltersJson));
        }
        catch (JsonException)
        {
            return BadRequestProblem("Les filtres doivent etre un JSON valide.");
        }

        return null;
    }

    private ActionResult? ValidateFavoriteRequest(FavoriteOfferRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Source)) return BadRequestProblem("La source est obligatoire.");
        if (string.IsNullOrWhiteSpace(request.ExternalOfferId)) return BadRequestProblem("L'identifiant externe est obligatoire.");
        if (string.IsNullOrWhiteSpace(request.Title)) return BadRequestProblem("Le titre de l'offre est obligatoire.");
        if (string.IsNullOrWhiteSpace(request.Url)) return BadRequestProblem("Le lien de l'offre est obligatoire.");
        return Uri.TryCreate(request.Url, UriKind.Absolute, out _)
            ? null
            : BadRequestProblem("Le lien de l'offre doit etre une URL valide.");
    }

    private static ApprenticeshipSearchResponse ToSearchResponse(ApprenticeshipSearch search) => new(
        search.Id,
        search.Name,
        search.Keywords,
        search.Location,
        search.Latitude,
        search.Longitude,
        search.DistanceKm,
        search.FiltersJson,
        search.AlertEnabled,
        search.LastCheckedAt,
        search.CreatedAt);

    private static FavoriteOfferResponse ToFavoriteResponse(FavoriteOffer offer) => new(
        offer.Id,
        offer.Source,
        offer.ExternalOfferId,
        offer.Title,
        offer.Company,
        offer.Location,
        offer.Url,
        offer.PublishedAt,
        offer.SavedAt);

    private static ApprenticeshipOpportunityResponse ToOpportunityResponse(ApprenticeshipOpportunity opportunity) => new(
        opportunity.Source,
        opportunity.ExternalId,
        opportunity.OpportunityType,
        opportunity.Title,
        opportunity.Company,
        opportunity.Location,
        opportunity.DistanceKm,
        opportunity.PublishedAt,
        opportunity.ExpiresAt,
        opportunity.ContractTypes,
        opportunity.TargetDiploma,
        opportunity.RemoteMode,
        opportunity.Summary,
        opportunity.ApplicationUrl);

    private async Task<ApplicationUser?> CurrentUserAsync() =>
        await userManager.FindByIdAsync(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    private static string NormalizeJson(string? value) =>
        string.IsNullOrWhiteSpace(value) ? "{}" : value.Trim();

    private static string? CleanOptional(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private ObjectResult BadRequestProblem(string title) =>
        BadRequest(new ProblemDetails { Title = title, Status = StatusCodes.Status400BadRequest });
}
