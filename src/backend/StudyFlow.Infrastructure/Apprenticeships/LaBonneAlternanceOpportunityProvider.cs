using System.Globalization;
using System.Net.Http.Headers;
using System.Text.Json;
using Microsoft.Extensions.Options;
using StudyFlow.Application.Apprenticeships;

namespace StudyFlow.Infrastructure.Apprenticeships;

public sealed class LaBonneAlternanceOpportunityProvider(
    HttpClient httpClient,
    IOptions<LaBonneAlternanceOptions> options) : IApprenticeshipOpportunityProvider
{
    private readonly LaBonneAlternanceOptions _options = options.Value;

    public async Task<IReadOnlyCollection<ApprenticeshipOpportunity>> SearchAsync(
        ApprenticeshipOpportunitySearchQuery query,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(_options.BaseUrl) || string.IsNullOrWhiteSpace(_options.AccessToken))
        {
            return _options.UseDemoWhenNotConfigured ? DemoResults(query) : [];
        }

        using var request = new HttpRequestMessage(HttpMethod.Get, BuildSearchUri(query));
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _options.AccessToken);

        using var response = await httpClient.SendAsync(request, cancellationToken);
        response.EnsureSuccessStatusCode();

        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
        return MapResponse(document.RootElement);
    }

    private Uri BuildSearchUri(ApprenticeshipOpportunitySearchQuery query)
    {
        var baseUri = new Uri(_options.BaseUrl!, UriKind.Absolute);
        var builder = new UriBuilder(new Uri(baseUri, _options.SearchPath));
        var parameters = new List<string> { $"keywords={Uri.EscapeDataString(query.Keywords)}" };

        if (!string.IsNullOrWhiteSpace(query.Location)) parameters.Add($"location={Uri.EscapeDataString(query.Location)}");
        if (query.Latitude is not null) parameters.Add($"latitude={query.Latitude.Value.ToString(CultureInfo.InvariantCulture)}");
        if (query.Longitude is not null) parameters.Add($"longitude={query.Longitude.Value.ToString(CultureInfo.InvariantCulture)}");
        if (query.DistanceKm is not null) parameters.Add($"radius={query.DistanceKm.Value.ToString(CultureInfo.InvariantCulture)}");
        if (query.RomeCodes.Count > 0) parameters.Add($"romes={Uri.EscapeDataString(string.Join(",", query.RomeCodes))}");

        builder.Query = string.Join("&", parameters);
        return builder.Uri;
    }

    private static IReadOnlyCollection<ApprenticeshipOpportunity> MapResponse(JsonElement root)
    {
        var items = TryGetArray(root, "results")
            ?? TryGetArray(root, "jobs")
            ?? TryGetArray(root, "data")
            ?? (root.ValueKind == JsonValueKind.Array ? root : default);

        if (items.ValueKind != JsonValueKind.Array) return [];

        var results = new List<ApprenticeshipOpportunity>();
        foreach (var item in items.EnumerateArray())
        {
            results.Add(new ApprenticeshipOpportunity(
                Source: "la-bonne-alternance",
                ExternalId: ReadString(item, "id") ?? ReadString(item, "job.id") ?? Guid.NewGuid().ToString("N"),
                OpportunityType: ReadString(item, "opportunityType") ?? ReadString(item, "type") ?? "offer",
                Title: ReadString(item, "title") ?? ReadString(item, "intitule") ?? ReadString(item, "job.title") ?? "Offre d'alternance",
                Company: ReadString(item, "company.name") ?? ReadString(item, "company") ?? ReadString(item, "etablissement.name"),
                Location: ReadString(item, "location") ?? ReadString(item, "place.city") ?? ReadString(item, "workplace.address.label"),
                DistanceKm: ReadDecimal(item, "distanceKm") ?? ReadDecimal(item, "distance"),
                PublishedAt: ReadDate(item, "publishedAt") ?? ReadDate(item, "createdAt"),
                ExpiresAt: ReadDate(item, "expiresAt"),
                ContractTypes: ReadStringArray(item, "contractTypes"),
                TargetDiploma: ReadString(item, "targetDiploma") ?? ReadString(item, "diploma"),
                RemoteMode: ReadString(item, "remoteMode"),
                Summary: ReadString(item, "summary") ?? ReadString(item, "description"),
                ApplicationUrl: ReadString(item, "url") ?? ReadString(item, "applicationUrl") ?? ReadString(item, "applyUrl") ?? "https://labonnealternance.apprentissage.beta.gouv.fr"));
        }

        return results;
    }

    private static IReadOnlyCollection<ApprenticeshipOpportunity> DemoResults(ApprenticeshipOpportunitySearchQuery query) =>
        [
            new ApprenticeshipOpportunity(
                Source: "demo",
                ExternalId: "demo-opportunity-1",
                OpportunityType: "offer",
                Title: $"Alternance {query.Keywords}",
                Company: "Entreprise locale",
                Location: query.Location ?? "France",
                DistanceKm: null,
                PublishedAt: DateTimeOffset.UtcNow.AddDays(-2),
                ExpiresAt: DateTimeOffset.UtcNow.AddDays(30),
                ContractTypes: ["apprentissage"],
                TargetDiploma: null,
                RemoteMode: null,
                Summary: "Résultat local utilisé tant que La Bonne Alternance n'est pas configurée sur le backend.",
                ApplicationUrl: "https://labonnealternance.apprentissage.beta.gouv.fr")
        ];

    private static JsonElement? TryGetArray(JsonElement root, string propertyName) =>
        root.TryGetProperty(propertyName, out var value) && value.ValueKind == JsonValueKind.Array ? value : null;

    private static string? ReadString(JsonElement element, string path)
    {
        var value = ReadElement(element, path);
        return value is { ValueKind: JsonValueKind.String } ? value.Value.GetString() : null;
    }

    private static decimal? ReadDecimal(JsonElement element, string path)
    {
        var value = ReadElement(element, path);
        return value is { ValueKind: JsonValueKind.Number } && value.Value.TryGetDecimal(out var number) ? number : null;
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
