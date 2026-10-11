using System.Globalization;
using System.Text.Json;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace StudyFlow.Infrastructure.Apprenticeships;

public sealed class GeocodingOptions
{
    public const string SectionName = "Geocoding";

    /// <summary>Géoplateforme de l'IGN (ex-API Adresse) : gratuite, sans clé.</summary>
    public string BaseUrl { get; set; } = "https://data.geopf.fr/geocodage";
}

public sealed record GeocodedCity(string Label, string CityCode, decimal Latitude, decimal Longitude);

/// <summary>
/// Transforme « Lille » ou « 59000 » en coordonnées et code INSEE : les sources d'offres cherchent
/// autour d'un point (La bonne alternance) ou d'une commune (France Travail), pas d'un texte libre.
/// </summary>
public sealed class CityGeocoder(
    HttpClient httpClient,
    IOptions<GeocodingOptions> options,
    ApprenticeshipSearchCache cache,
    ILogger<CityGeocoder> logger)
{
    private const double MinimumScore = 0.4;
    private static readonly TimeSpan Lifetime = TimeSpan.FromDays(1);

    public async Task<GeocodedCity?> FindAsync(string location, CancellationToken cancellationToken = default)
    {
        var text = location.Trim();
        if (text.Length < 2) return null;

        var key = $"geocode|{text.ToLowerInvariant()}";
        if (cache.Entries.TryGetValue(key, out GeocodedCity? cached)) return cached;

        GeocodedCity? city;
        try
        {
            city = await QueryAsync(text, cancellationToken);
        }
        catch (Exception exception) when (!cancellationToken.IsCancellationRequested)
        {
            // Sans coordonnées, chaque source se rabat sur la ville en texte ou sur toute la France.
            logger.LogWarning(exception, "Geocoding failed for the apprenticeship search location.");
            return null;
        }

        cache.Entries.Set(key, city, new MemoryCacheEntryOptions { AbsoluteExpirationRelativeToNow = Lifetime, Size = 1 });
        return city;
    }

    private async Task<GeocodedCity?> QueryAsync(string text, CancellationToken cancellationToken)
    {
        var uri = $"{options.Value.BaseUrl.TrimEnd('/')}/search?q={Uri.EscapeDataString(text)}&type=municipality&limit=1";
        using var response = await httpClient.GetAsync(uri, cancellationToken);
        response.EnsureSuccessStatusCode();

        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
        if (!document.RootElement.TryGetProperty("features", out var features)
            || features.ValueKind != JsonValueKind.Array
            || features.GetArrayLength() == 0)
        {
            return null;
        }

        var feature = features[0];
        var properties = feature.GetProperty("properties");
        var score = properties.TryGetProperty("score", out var scoreValue) && scoreValue.ValueKind == JsonValueKind.Number
            ? scoreValue.GetDouble()
            : 0;
        if (score < MinimumScore) return null;

        var coordinates = feature.GetProperty("geometry").GetProperty("coordinates");
        var label = properties.TryGetProperty("city", out var cityValue) && cityValue.ValueKind == JsonValueKind.String
            ? cityValue.GetString()!
            : properties.GetProperty("label").GetString() ?? text;

        return new GeocodedCity(
            label,
            properties.GetProperty("citycode").GetString() ?? "",
            Math.Round(coordinates[1].GetDecimal(), 5),
            Math.Round(coordinates[0].GetDecimal(), 5));
    }

    public static string Format(decimal value) => value.ToString(CultureInfo.InvariantCulture);
}
