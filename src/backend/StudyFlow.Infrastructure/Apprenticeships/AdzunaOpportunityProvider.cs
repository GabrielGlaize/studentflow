using System.Globalization;
using System.Text.Json;
using Microsoft.Extensions.Options;
using StudyFlow.Application.Apprenticeships;

namespace StudyFlow.Infrastructure.Apprenticeships;

public sealed class AdzunaOpportunityProvider(
    HttpClient httpClient,
    IOptions<AdzunaOptions> options) : IApprenticeshipOpportunityProvider
{
    private readonly AdzunaOptions _options = options.Value;

    public async Task<IReadOnlyCollection<ApprenticeshipOpportunity>> SearchAsync(
        ApprenticeshipOpportunitySearchQuery query,
        CancellationToken cancellationToken = default)
    {
        if (!IsConfigured())
        {
            return _options.UseDemoWhenNotConfigured ? DemoResults(query) : [];
        }

        using var response = await httpClient.GetAsync(BuildSearchUri(query), cancellationToken);
        response.EnsureSuccessStatusCode();

        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
        return MapResponse(document.RootElement);
    }

    private bool IsConfigured() =>
        !string.IsNullOrWhiteSpace(_options.BaseUrl)
        && !string.IsNullOrWhiteSpace(_options.Country)
        && !string.IsNullOrWhiteSpace(_options.AppId)
        && !string.IsNullOrWhiteSpace(_options.AppKey);

    private Uri BuildSearchUri(ApprenticeshipOpportunitySearchQuery query)
    {
        var baseUri = new Uri(_options.BaseUrl!, UriKind.Absolute);
        var country = Uri.EscapeDataString(_options.Country.Trim().ToLowerInvariant());
        var builder = new UriBuilder(new Uri(baseUri, $"/v1/api/jobs/{country}/search/1"));

        var keywords = query.Keywords.Contains("alternance", StringComparison.OrdinalIgnoreCase)
            ? query.Keywords.Trim()
            : $"alternance {query.Keywords.Trim()}";

        var parameters = new List<string>
        {
            $"app_id={Uri.EscapeDataString(_options.AppId!)}",
            $"app_key={Uri.EscapeDataString(_options.AppKey!)}",
            $"what={Uri.EscapeDataString(keywords)}",
            $"results_per_page={Math.Clamp(_options.ResultsPerPage, 1, 50)}",
            "sort_by=date"
        };

        if (!string.IsNullOrWhiteSpace(query.Location))
        {
            parameters.Add($"where={Uri.EscapeDataString(query.Location)}");
        }

        if (query.DistanceKm is not null)
        {
            parameters.Add($"distance={query.DistanceKm.Value.ToString(CultureInfo.InvariantCulture)}");
        }

        builder.Query = string.Join("&", parameters);
        return builder.Uri;
    }

    private static IReadOnlyCollection<ApprenticeshipOpportunity> MapResponse(JsonElement root)
    {
        if (!root.TryGetProperty("results", out var items) || items.ValueKind != JsonValueKind.Array)
        {
            return [];
        }

        var results = new List<ApprenticeshipOpportunity>();
        foreach (var item in items.EnumerateArray())
        {
            var redirectUrl = ReadString(item, "redirect_url");
            if (string.IsNullOrWhiteSpace(redirectUrl)) continue;

            results.Add(new ApprenticeshipOpportunity(
                Source: "adzuna",
                ExternalId: ReadString(item, "id") ?? Guid.NewGuid().ToString("N"),
                OpportunityType: "offer",
                Title: ReadString(item, "title") ?? "Offre d'alternance",
                Company: ReadString(item, "company.display_name"),
                Location: ReadString(item, "location.display_name"),
                DistanceKm: null,
                PublishedAt: ReadDate(item, "created"),
                ExpiresAt: null,
                ContractTypes: ReadString(item, "contract_type") is { } contractType
                    ? [contractType]
                    : ["alternance"],
                TargetDiploma: null,
                RemoteMode: null,
                Summary: CleanSummary(ReadString(item, "description")),
                ApplicationUrl: redirectUrl));
        }

        return results;
    }

    private static IReadOnlyCollection<ApprenticeshipOpportunity> DemoResults(ApprenticeshipOpportunitySearchQuery query) =>
        [
            new ApprenticeshipOpportunity(
                Source: "demo-adzuna",
                ExternalId: "demo-adzuna-1",
                OpportunityType: "offer",
                Title: $"Alternance {query.Keywords}",
                Company: "Atelier Numérique",
                Location: query.Location ?? "France",
                DistanceKm: null,
                PublishedAt: DateTimeOffset.UtcNow.AddDays(-1),
                ExpiresAt: DateTimeOffset.UtcNow.AddDays(30),
                ContractTypes: ["alternance"],
                TargetDiploma: null,
                RemoteMode: null,
                Summary: "Résultat de démonstration utilisé tant qu'Adzuna n'est pas configuré sur le backend.",
                ApplicationUrl: "https://www.adzuna.fr")
        ];

    private static string? CleanSummary(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;

        var clean = value
            .Replace("<strong>", string.Empty, StringComparison.OrdinalIgnoreCase)
            .Replace("</strong>", string.Empty, StringComparison.OrdinalIgnoreCase)
            .Replace("<br>", " ", StringComparison.OrdinalIgnoreCase)
            .Replace("<br/>", " ", StringComparison.OrdinalIgnoreCase)
            .Replace("<br />", " ", StringComparison.OrdinalIgnoreCase)
            .Trim();

        return clean.Length <= 500 ? clean : $"{clean[..500]}…";
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
