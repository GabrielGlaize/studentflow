using System.Net.Http.Json;
using StudyFlow.Api.Contracts;
using StudyFlow.Api.Tests.Infrastructure;

namespace StudyFlow.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class AppSettingsTests(ApiFixture fixture)
{
    [Fact]
    public async Task Default_settings_say_they_were_never_saved_so_the_app_keeps_its_own()
    {
        var session = await fixture.Api.RegisterAsync();
        var client = fixture.Api.As(session);

        var initial = await client.GetFromJsonAsync<ProfileResponse>("/api/v1/profile", ApiScenario.Json);
        Assert.Null(initial!.AppSettings.UpdatedAt);
        Assert.False(initial.AppSettings.HasCompany);

        // Relire ne change rien : seule une vraie modification compte comme enregistrement.
        var reread = await client.GetFromJsonAsync<ProfileResponse>("/api/v1/profile", ApiScenario.Json);
        Assert.Null(reread!.AppSettings.UpdatedAt);

        var saved = await client.PutAsJsonAsync("/api/v1/profile/app-settings",
            new AppSettingsRequest("dark", true, "Atelier Numérique", "company"));
        var settings = await saved.ReadSuccessAsync<AppSettingsResponse>();
        Assert.NotNull(settings.UpdatedAt);
        Assert.Equal("Atelier Numérique", settings.CompanyName);

        var afterSave = await client.GetFromJsonAsync<ProfileResponse>("/api/v1/profile", ApiScenario.Json);
        Assert.Equal(settings.UpdatedAt, afterSave!.AppSettings.UpdatedAt);
        Assert.True(afterSave.AppSettings.HasCompany);
    }
}
