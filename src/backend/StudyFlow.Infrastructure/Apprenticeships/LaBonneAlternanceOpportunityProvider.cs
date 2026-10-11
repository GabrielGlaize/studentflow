using System.Globalization;
using System.Net.Http.Headers;
using System.Text.Json;
using Microsoft.Extensions.Options;
using StudyFlow.Application.Apprenticeships;

namespace StudyFlow.Infrastructure.Apprenticeships;

/// <summary>
/// GET /job/v1/search de l'API La bonne alternance. Elle cherche autour d'un point GPS et par codes ROME ;
/// sans code ROME reconnu, les offres de la zone sont filtrées sur les mots-clés.
/// </summary>
public sealed class LaBonneAlternanceOpportunityProvider(
    HttpClient httpClient,
    IOptions<LaBonneAlternanceOptions> options) : IExternalOpportunitySource
{
    private const string WebsiteUrl = "https://labonnealternance.apprentissage.beta.gouv.fr";
    private readonly LaBonneAlternanceOptions _options = options.Value;

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(_options.BaseUrl) && !string.IsNullOrWhiteSpace(_options.AccessToken);

    public async Task<IReadOnlyCollection<ApprenticeshipOpportunity>> SearchAsync(
        ApprenticeshipOpportunitySearchQuery query,
        CancellationToken cancellationToken = default)
    {
        if (!IsConfigured) return [];

        var romeCodes = query.RomeCodes.Count > 0 ? query.RomeCodes : RomeCodeCatalog.Match(query.Keywords);
        using var request = new HttpRequestMessage(HttpMethod.Get, BuildSearchUri(query, romeCodes));
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _options.AccessToken);

        using var response = await httpClient.SendAsync(request, cancellationToken);
        response.EnsureSuccessStatusCode();

        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
        var offers = MapResponse(document.RootElement, query);

        // Les codes ROME ciblent déjà le métier ; sinon, on garde les offres qui citent les mots-clés.
        if (romeCodes.Count == 0) offers = FilterByKeywords(offers, query.Keywords);

        return offers.Take(Math.Clamp(_options.MaxResults, 1, 150)).ToArray();
    }

    private Uri BuildSearchUri(ApprenticeshipOpportunitySearchQuery query, IReadOnlyCollection<string> romeCodes)
    {
        var builder = new UriBuilder($"{_options.BaseUrl.TrimEnd('/')}/job/v1/search");
        var parameters = new List<string>();

        if (query.Latitude is not null && query.Longitude is not null)
        {
            parameters.Add($"latitude={query.Latitude.Value.ToString(CultureInfo.InvariantCulture)}");
            parameters.Add($"longitude={query.Longitude.Value.ToString(CultureInfo.InvariantCulture)}");
            parameters.Add($"radius={Math.Clamp(SearchDefaults.DistanceOrDefault(query), 1, 200)}");
        }

        if (romeCodes.Count > 0) parameters.Add($"romes={Uri.EscapeDataString(string.Join(",", romeCodes))}");

        builder.Query = string.Join("&", parameters);
        return builder.Uri;
    }

    public static List<ApprenticeshipOpportunity> MapResponse(JsonElement root, ApprenticeshipOpportunitySearchQuery query)
    {
        var results = new List<ApprenticeshipOpportunity>();
        if (!root.TryGetProperty("jobs", out var jobs) || jobs.ValueKind != JsonValueKind.Array) return results;

        foreach (var job in jobs.EnumerateArray())
        {
            var title = ReadString(job, "offer.title");
            if (string.IsNullOrWhiteSpace(title)) continue;

            var coordinates = ReadElement(job, "workplace.location.geopoint.coordinates");
            decimal? longitude = null, latitude = null;
            if (coordinates is { ValueKind: JsonValueKind.Array } point && point.GetArrayLength() >= 2
                && point[0].TryGetDecimal(out var lon) && point[1].TryGetDecimal(out var lat))
            {
                longitude = lon;
                latitude = lat;
            }

            var contractTypes = ReadStringArray(job, "contract.type");
            results.Add(new ApprenticeshipOpportunity(
                Source: "la-bonne-alternance",
                ExternalId: ReadString(job, "identifier.id") ?? ReadString(job, "identifier.partner_job_id") ?? Guid.NewGuid().ToString("N"),
                OpportunityType: "offer",
                Title: title.Trim(),
                Company: ReadString(job, "workplace.name") ?? ReadString(job, "workplace.brand") ?? ReadString(job, "workplace.legal_name"),
                Location: ReadString(job, "workplace.location.address"),
                DistanceKm: SearchDefaults.DistanceKmFrom(query, latitude, longitude),
                PublishedAt: ReadDate(job, "offer.publication.creation"),
                ExpiresAt: ReadDate(job, "offer.publication.expiration"),
                ContractTypes: contractTypes.Count > 0 ? contractTypes : ["alternance"],
                TargetDiploma: ReadString(job, "offer.target_diploma.label"),
                RemoteMode: ReadString(job, "contract.remote"),
                Summary: SearchDefaults.CleanSummary(ReadString(job, "offer.description")),
                ApplicationUrl: ReadString(job, "apply.url") ?? WebsiteUrl));
        }

        return results;
    }

    public static List<ApprenticeshipOpportunity> FilterByKeywords(
        List<ApprenticeshipOpportunity> offers,
        string keywords)
    {
        var words = RomeCodeCatalog.Words(keywords);
        if (words.Length == 0) return offers;

        return offers
            .Where(offer =>
            {
                var text = RomeCodeCatalog.RemoveDiacritics($"{offer.Title} {offer.Summary}".ToLowerInvariant());
                return words.Any(word => text.Contains(word, StringComparison.Ordinal));
            })
            .ToList();
    }

    private static string? ReadString(JsonElement element, string path)
    {
        var value = ReadElement(element, path);
        return value is { ValueKind: JsonValueKind.String } ? value.Value.GetString() : null;
    }

    private static DateTimeOffset? ReadDate(JsonElement element, string path)
    {
        var value = ReadElement(element, path);
        if (value is not { ValueKind: JsonValueKind.String }) return null;
        return DateTimeOffset.TryParse(value.Value.GetString(), CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var date)
            ? date
            : null;
    }

    private static IReadOnlyCollection<string> ReadStringArray(JsonElement element, string path)
    {
        var value = ReadElement(element, path);
        if (value is not { ValueKind: JsonValueKind.Array }) return [];

        return value.Value.EnumerateArray()
            .Where(x => x.ValueKind == JsonValueKind.String)
            .Select(x => x.GetString()!)
            .ToArray();
    }

    private static JsonElement? ReadElement(JsonElement element, string path)
    {
        var current = element;
        foreach (var part in path.Split('.'))
        {
            if (current.ValueKind != JsonValueKind.Object || !current.TryGetProperty(part, out current)) return null;
        }

        return current;
    }
}
