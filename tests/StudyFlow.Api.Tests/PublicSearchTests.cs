using System.Net;
using System.Net.Http.Json;
using StudyFlow.Api.Contracts;
using StudyFlow.Api.Tests.Infrastructure;

namespace StudyFlow.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class PublicSearchTests(ApiFixture fixture)
{
    [Fact]
    public async Task A_visitor_can_search_without_an_account_and_demo_offers_are_flagged()
    {
        var offers = await fixture.Api.Anonymous().GetFromJsonAsync<ApprenticeshipOpportunityResponse[]>(
            "/api/v1/public/alternances?keywords=developpeur&location=Lyon", ApiScenario.Json);

        Assert.NotEmpty(offers!);
        Assert.All(offers!, offer => Assert.True(offer.IsDemo));
    }

    [Fact]
    public async Task Public_search_is_rate_limited_per_visitor()
    {
        await using var api = fixture.CreateFactory(new Dictionary<string, string?>
        {
            ["RateLimiting:PublicSearch:PermitLimit"] = "2"
        });
        var client = api.Anonymous();

        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/v1/public/alternances?keywords=design")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/v1/public/alternances?keywords=design")).StatusCode);
        Assert.Equal(HttpStatusCode.TooManyRequests, (await client.GetAsync("/api/v1/public/alternances?keywords=design")).StatusCode);
    }

    [Fact]
    public async Task Search_parameters_are_bounded()
    {
        var client = fixture.Api.Anonymous();

        var tooFar = await client.GetAsync("/api/v1/public/alternances?keywords=design&distanceKm=5000");
        Assert.Equal(HttpStatusCode.BadRequest, tooFar.StatusCode);

        var tooLong = await client.GetAsync($"/api/v1/public/alternances?keywords={new string('a', 201)}");
        Assert.Equal(HttpStatusCode.BadRequest, tooLong.StatusCode);
    }
}
