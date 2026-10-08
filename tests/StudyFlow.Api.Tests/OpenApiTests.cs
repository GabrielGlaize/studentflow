using System.Net;
using StudyFlow.Api.Tests.Infrastructure;

namespace StudyFlow.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class OpenApiTests(ApiFixture fixture)
{
    [Fact]
    public async Task The_swagger_document_is_generated_when_enabled()
    {
        await using var api = fixture.CreateFactory(new Dictionary<string, string?> { ["OpenApi:Enabled"] = "true" });

        var response = await api.Anonymous().GetAsync("/swagger/v1/swagger.json");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Contains("/api/v1/public/alternances", await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task Swagger_is_not_exposed_by_default()
    {
        var response = await fixture.Api.Anonymous().GetAsync("/swagger/v1/swagger.json");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }
}
