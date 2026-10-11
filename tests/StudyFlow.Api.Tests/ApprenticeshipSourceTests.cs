using System.Text.Json;
using StudyFlow.Application.Apprenticeships;
using StudyFlow.Infrastructure.Apprenticeships;

namespace StudyFlow.Api.Tests;

/// <summary>Traduction des réponses des sources d'offres, sans appel réseau ni base de données.</summary>
public sealed class ApprenticeshipSourceTests
{
    [Theory]
    [InlineData("Développeur web", "M1805")]
    [InlineData("assistant RH", "M1501")]
    [InlineData("comptabilité", "M1203")]
    [InlineData("CAP boulanger", "D1102")]
    public void Common_fields_are_translated_into_rome_codes(string keywords, string expectedCode)
    {
        Assert.Contains(expectedCode, RomeCodeCatalog.Match(keywords));
    }

    [Fact]
    public void Short_stems_only_match_whole_words()
    {
        // « ui » (design d'interface) ne doit pas reconnaître « cuisine », ni « rh » un autre mot.
        var codes = RomeCodeCatalog.Match("cuisinier");
        Assert.DoesNotContain("E1205", codes);
        Assert.Contains("G1602", codes);
        Assert.Empty(RomeCodeCatalog.Match("alternance"));
    }

    [Fact]
    public void La_bonne_alternance_offers_are_mapped_with_their_distance()
    {
        using var document = JsonDocument.Parse("""
            {
              "jobs": [{
                "identifier": { "id": "abc", "partner_label": "La bonne alternance", "partner_job_id": "p1" },
                "workplace": {
                  "name": "Boulangerie Ange",
                  "location": { "address": "12 rue de Paris 59000 Lille", "geopoint": { "type": "Point", "coordinates": [3.0634, 50.6372] } }
                },
                "apply": { "url": "https://labonnealternance.apprentissage.beta.gouv.fr/offre/abc" },
                "contract": { "type": ["Apprentissage"], "remote": "onsite" },
                "offer": {
                  "title": "CAP Boulanger",
                  "description": "<p>Tu apprends <strong>le pain</strong> &amp; la viennoiserie.</p>",
                  "publication": { "creation": "2026-10-01T08:00:00Z", "expiration": "2026-12-01T08:00:00Z" },
                  "target_diploma": { "european": "3", "label": "CAP" }
                }
              }],
              "recruiters": [],
              "warnings": []
            }
            """);
        var query = new ApprenticeshipOpportunitySearchQuery("boulanger", "Lille", 50.6311m, 3.0468m, null, []);

        var offer = Assert.Single(LaBonneAlternanceOpportunityProvider.MapResponse(document.RootElement, query));

        Assert.Equal("CAP Boulanger", offer.Title);
        Assert.Equal("Boulangerie Ange", offer.Company);
        Assert.Equal(["Apprentissage"], offer.ContractTypes);
        Assert.Equal("CAP", offer.TargetDiploma);
        Assert.Equal("Tu apprends le pain & la viennoiserie.", offer.Summary);
        Assert.InRange(offer.DistanceKm!.Value, 1m, 2m);
        Assert.False(offer.IsDemo);
    }

    [Fact]
    public void Without_rome_codes_offers_are_filtered_on_the_keywords_ignoring_accents()
    {
        List<ApprenticeshipOpportunity> offers =
        [
            Offer("Assistant(e) événementiel"),
            Offer("Préparateur de commandes")
        ];

        var kept = LaBonneAlternanceOpportunityProvider.FilterByKeywords(offers, "evenementiel");

        Assert.Equal("Assistant(e) événementiel", Assert.Single(kept).Title);
    }

    private static ApprenticeshipOpportunity Offer(string title) => new(
        "la-bonne-alternance", Guid.NewGuid().ToString("N"), "offer", title, "Entreprise", "Lille",
        null, null, null, ["Apprentissage"], null, null, null, "https://example.test");
}
