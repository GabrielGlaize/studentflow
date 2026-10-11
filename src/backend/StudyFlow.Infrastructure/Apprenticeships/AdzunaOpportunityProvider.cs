using System.Globalization;
using System.Text.Json;
using Microsoft.Extensions.Options;
using StudyFlow.Application.Apprenticeships;

namespace StudyFlow.Infrastructure.Apprenticeships;

public sealed class AdzunaOpportunityProvider(
    HttpClient httpClient,
    IOptions<AdzunaOptions> options) : IExternalOpportunitySource
{
    private readonly AdzunaOptions _options = options.Value;

    public async Task<IReadOnlyCollection<ApprenticeshipOpportunity>> SearchAsync(
        ApprenticeshipOpportunitySearchQuery query,
        CancellationToken cancellationToken = default)
    {
        if (!IsConfigured) return [];

        using var response = await httpClient.GetAsync(BuildSearchUri(query), cancellationToken);
        response.EnsureSuccessStatusCode();

        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
        return MapResponse(document.RootElement, query);
    }

    private const string ApprenticeshipWords = "alternance alternant alternante apprenti apprentie apprentissage";

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(_options.BaseUrl)
        && !string.IsNullOrWhiteSpace(_options.Country)
        && !string.IsNullOrWhiteSpace(_options.AppId)
        && !string.IsNullOrWhiteSpace(_options.AppKey);

    private Uri BuildSearchUri(ApprenticeshipOpportunitySearchQuery query)
    {
        var baseUri = new Uri(_options.BaseUrl!, UriKind.Absolute);
        var country = Uri.EscapeDataString(_options.Country.Trim().ToLowerInvariant());
        var builder = new UriBuilder(new Uri(baseUri, $"/v1/api/jobs/{country}/search/1"));

        // Les mots-clés de l'élève sont tous exigés ; au moins un mot d'alternance aussi. Tri par
        // pertinence (le tri par date d'Adzuna fait remonter des CDI qui citent l'alternance en passant).
        var keywords = string.Join(' ', RomeCodeCatalog.Words(query.Keywords));
        var parameters = new List<string>
        {
            $"app_id={Uri.EscapeDataString(_options.AppId!)}",
            $"app_key={Uri.EscapeDataString(_options.AppKey!)}",
            $"what_or={Uri.EscapeDataString(ApprenticeshipWords)}",
            $"results_per_page={Math.Clamp(_options.ResultsPerPage, 1, 50)}"
        };

        if (keywords.Length > 0) parameters.Add($"what={Uri.EscapeDataString(keywords)}");

        if (!string.IsNullOrWhiteSpace(query.Location))
        {
            parameters.Add($"where={Uri.EscapeDataString(query.Location)}");
        }

        if (!string.IsNullOrWhiteSpace(query.Location))
        {
            // Sans distance, Adzuna ne cherche qu'à 5 km du centre-ville.
            parameters.Add($"distance={SearchDefaults.DistanceOrDefault(query).ToString(CultureInfo.InvariantCulture)}");
        }

        builder.Query = string.Join("&", parameters);
        return builder.Uri;
    }

    private static IReadOnlyCollection<ApprenticeshipOpportunity> MapResponse(
        JsonElement root,
        ApprenticeshipOpportunitySearchQuery query)
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

            var title = ReadString(item, "title") ?? "Offre d'alternance";
            var description = ReadString(item, "description");
            if (!MentionsApprenticeship($"{title} {description}")) continue;

            results.Add(new ApprenticeshipOpportunity(
                Source: "adzuna",
                ExternalId: ReadString(item, "id") ?? Guid.NewGuid().ToString("N"),
                OpportunityType: "offer",
                Title: title.Trim(),
                Company: ReadString(item, "company.display_name"),
                Location: ReadString(item, "location.display_name"),
                DistanceKm: SearchDefaults.DistanceKmFrom(query, ReadDecimal(item, "latitude"), ReadDecimal(item, "longitude")),
                PublishedAt: ReadDate(item, "created"),
                ExpiresAt: null,
                // contract_type d'Adzuna (« permanent », « contract ») ne dit rien d'une alternance.
                ContractTypes: ["alternance"],
                TargetDiploma: null,
                RemoteMode: null,
                Summary: SearchDefaults.CleanSummary(description),
                ApplicationUrl: redirectUrl));
        }

        return results;
    }



    private static string? ReadString(JsonElement element, string path)
    {
        var value = ReadElement(element, path);
        return value is { ValueKind: JsonValueKind.String } ? value.Value.GetString() : null;
    }

    /// <summary>Un CDI qui mentionne l'alternance au détour d'une phrase n'en est pas une.</summary>
    private static bool MentionsApprenticeship(string text)
    {
        var normalized = RomeCodeCatalog.RemoveDiacritics(text.ToLowerInvariant());
        return normalized.Contains("altern", StringComparison.Ordinal)
            || normalized.Contains("apprenti", StringComparison.Ordinal)
            || normalized.Contains("professionnalisation", StringComparison.Ordinal);
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
