using System.Globalization;
using System.Net.Http.Headers;
using System.Text.Json;
using Microsoft.Extensions.Options;
using StudyFlow.Application.Apprenticeships;

namespace StudyFlow.Infrastructure.Apprenticeships;

public sealed class FranceTravailOpportunityProvider(
    HttpClient httpClient,
    IOptions<FranceTravailOptions> options) : IApprenticeshipOpportunityProvider
{
    private readonly FranceTravailOptions _options = options.Value;
    private string? _accessToken;
    private DateTimeOffset _accessTokenExpiresAt;

    public async Task<IReadOnlyCollection<ApprenticeshipOpportunity>> SearchAsync(
        ApprenticeshipOpportunitySearchQuery query,
        CancellationToken cancellationToken = default)
    {
        if (!IsConfigured())
        {
            return _options.UseDemoWhenNotConfigured ? DemoResults(query) : [];
        }

        var token = await GetAccessTokenAsync(cancellationToken);
        using var request = new HttpRequestMessage(HttpMethod.Get, BuildSearchUri(query));
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);

        using var response = await httpClient.SendAsync(request, cancellationToken);
        response.EnsureSuccessStatusCode();

        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
        return MapResponse(document.RootElement);
    }

    private bool IsConfigured() =>
        !string.IsNullOrWhiteSpace(_options.TokenUrl)
        && !string.IsNullOrWhiteSpace(_options.SearchUrl)
        && !string.IsNullOrWhiteSpace(_options.ClientId)
        && !string.IsNullOrWhiteSpace(_options.ClientSecret);

    private async Task<string> GetAccessTokenAsync(CancellationToken cancellationToken)
    {
        if (!string.IsNullOrWhiteSpace(_accessToken)
            && _accessTokenExpiresAt > DateTimeOffset.UtcNow.AddMinutes(1))
        {
            return _accessToken;
        }

        var tokenUrl = new UriBuilder(_options.TokenUrl!);
        var tokenQuery = new List<string>();
        if (!string.IsNullOrWhiteSpace(_options.Realm))
        {
            tokenQuery.Add($"realm={Uri.EscapeDataString(_options.Realm)}");
        }

        tokenUrl.Query = string.Join("&", tokenQuery);

        using var content = new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["grant_type"] = "client_credentials",
            ["client_id"] = _options.ClientId!,
            ["client_secret"] = _options.ClientSecret!,
            ["scope"] = _options.Scope
        });

        using var response = await httpClient.PostAsync(tokenUrl.Uri, content, cancellationToken);
        response.EnsureSuccessStatusCode();

        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);

        _accessToken = ReadString(document.RootElement, "access_token")
            ?? throw new InvalidOperationException("France Travail n'a pas renvoyé de jeton d'accès.");

        var expiresIn = ReadInt(document.RootElement, "expires_in") ?? 300;
        _accessTokenExpiresAt = DateTimeOffset.UtcNow.AddSeconds(Math.Max(60, expiresIn));
        return _accessToken;
    }

    private Uri BuildSearchUri(ApprenticeshipOpportunitySearchQuery query)
    {
        var builder = new UriBuilder(_options.SearchUrl!);
        var keywords = query.Keywords.Contains("alternance", StringComparison.OrdinalIgnoreCase)
            ? query.Keywords.Trim()
            : $"alternance {query.Keywords.Trim()}";

        var parameters = new List<string>
        {
            $"motsCles={Uri.EscapeDataString(keywords)}",
            $"range=0-{Math.Clamp(_options.ResultsPerPage, 1, 50) - 1}"
        };

        if (!string.IsNullOrWhiteSpace(query.Location))
        {
            parameters.Add($"lieu={Uri.EscapeDataString(query.Location)}");
        }

        if (query.DistanceKm is not null)
        {
            parameters.Add($"distance={Math.Clamp(query.DistanceKm.Value, 0, 100)}");
        }

        if (query.RomeCodes.Count > 0)
        {
            parameters.Add($"codeROME={Uri.EscapeDataString(string.Join(",", query.RomeCodes))}");
        }

        builder.Query = string.Join("&", parameters);
        return builder.Uri;
    }

    private static IReadOnlyCollection<ApprenticeshipOpportunity> MapResponse(JsonElement root)
    {
        var items = TryGetArray(root, "resultats")
            ?? TryGetArray(root, "results")
            ?? TryGetArray(root, "data")
            ?? (root.ValueKind == JsonValueKind.Array ? root : default);

        if (items.ValueKind != JsonValueKind.Array) return [];

        var results = new List<ApprenticeshipOpportunity>();
        foreach (var item in items.EnumerateArray())
        {
            var title = ReadString(item, "intitule") ?? ReadString(item, "title");
            if (string.IsNullOrWhiteSpace(title)) continue;

            var applicationUrl = ReadString(item, "origineOffre.urlOrigine")
                ?? ReadString(item, "url")
                ?? ReadString(item, "applicationUrl")
                ?? "https://candidat.francetravail.fr/offres/recherche";

            results.Add(new ApprenticeshipOpportunity(
                Source: "france-travail",
                ExternalId: ReadString(item, "id") ?? Guid.NewGuid().ToString("N"),
                OpportunityType: "offer",
                Title: title,
                Company: ReadString(item, "entreprise.nom") ?? ReadString(item, "company.name"),
                Location: ReadString(item, "lieuTravail.libelle") ?? ReadString(item, "lieuTravail.commune") ?? ReadString(item, "location"),
                DistanceKm: null,
                PublishedAt: ReadDate(item, "dateCreation") ?? ReadDate(item, "dateActualisation"),
                ExpiresAt: null,
                ContractTypes: ReadString(item, "typeContratLibelle") is { } contractType
                    ? [contractType]
                    : ["alternance"],
                TargetDiploma: null,
                RemoteMode: ReadString(item, "modeTravailLibelle"),
                Summary: CleanSummary(ReadString(item, "description")),
                ApplicationUrl: applicationUrl));
        }

        return results;
    }

    private static IReadOnlyCollection<ApprenticeshipOpportunity> DemoResults(ApprenticeshipOpportunitySearchQuery query) =>
        [
            new ApprenticeshipOpportunity(
                Source: "demo-france-travail",
                ExternalId: "demo-france-travail-1",
                OpportunityType: "offer",
                Title: $"Alternance {query.Keywords}",
                Company: "Entreprise partenaire",
                Location: query.Location ?? "France",
                DistanceKm: null,
                PublishedAt: DateTimeOffset.UtcNow.AddDays(-1),
                ExpiresAt: null,
                ContractTypes: ["alternance"],
                TargetDiploma: null,
                RemoteMode: null,
                Summary: "Résultat de démonstration utilisé tant que France Travail n'est pas configuré.",
                ApplicationUrl: "https://candidat.francetravail.fr/offres/recherche")
        ];

    private static string? CleanSummary(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;

        var clean = value
            .Replace("<br>", " ", StringComparison.OrdinalIgnoreCase)
            .Replace("<br/>", " ", StringComparison.OrdinalIgnoreCase)
            .Replace("<br />", " ", StringComparison.OrdinalIgnoreCase)
            .Trim();

        return clean.Length <= 500 ? clean : $"{clean[..500]}…";
    }

    private static JsonElement? TryGetArray(JsonElement root, string propertyName) =>
        root.TryGetProperty(propertyName, out var value) && value.ValueKind == JsonValueKind.Array ? value : null;

    private static string? ReadString(JsonElement element, string path)
    {
        var value = ReadElement(element, path);
        return value is { ValueKind: JsonValueKind.String } ? value.Value.GetString() : null;
    }

    private static int? ReadInt(JsonElement element, string path)
    {
        var value = ReadElement(element, path);
        return value is { ValueKind: JsonValueKind.Number } && value.Value.TryGetInt32(out var number) ? number : null;
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
