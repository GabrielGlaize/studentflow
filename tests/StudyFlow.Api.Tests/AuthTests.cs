using System.Net;
using System.Net.Http.Json;
using StudyFlow.Api.Contracts;
using StudyFlow.Api.Tests.Infrastructure;
using StudyFlow.Application.Security;

namespace StudyFlow.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class AuthTests(ApiFixture fixture)
{
    [Fact]
    public async Task Login_locks_the_account_after_five_wrong_passwords()
    {
        var email = ApiScenario.NewEmail();
        await fixture.Api.RegisterAsync(email);
        var client = fixture.Api.Anonymous();

        for (var attempt = 0; attempt < 5; attempt++)
        {
            var failed = await client.PostAsJsonAsync("/api/v1/auth/login", new LoginRequest(email, "Mauvais123!"));
            Assert.Equal(HttpStatusCode.Unauthorized, failed.StatusCode);
        }

        // Même le bon mot de passe est refusé pendant le verrouillage.
        var locked = await client.PostAsJsonAsync("/api/v1/auth/login", new LoginRequest(email, ApiScenario.Password));
        Assert.Equal(HttpStatusCode.Unauthorized, locked.StatusCode);
    }

    [Fact]
    public async Task Successful_login_resets_the_failure_counter()
    {
        var email = ApiScenario.NewEmail();
        await fixture.Api.RegisterAsync(email);
        var client = fixture.Api.Anonymous();

        for (var attempt = 0; attempt < 4; attempt++)
        {
            await client.PostAsJsonAsync("/api/v1/auth/login", new LoginRequest(email, "Mauvais123!"));
        }

        await fixture.Api.LoginAsync(email);
        await client.PostAsJsonAsync("/api/v1/auth/login", new LoginRequest(email, "Mauvais123!"));

        await fixture.Api.LoginAsync(email);
    }

    [Fact]
    public async Task Refresh_has_its_own_limit_so_a_shared_ip_is_not_logged_out()
    {
        await using var api = fixture.CreateFactory(new Dictionary<string, string?>
        {
            ["RateLimiting:Credentials:PermitLimit"] = "3"
        });
        var session = await api.RegisterAsync();
        var client = api.Anonymous();

        // Bien plus de renouvellements que la limite "identifiants" : ils doivent tous passer.
        var refreshToken = session.Tokens.RefreshToken;
        for (var index = 0; index < 10; index++)
        {
            var refreshed = await client.PostAsJsonAsync("/api/v1/auth/refresh", new RefreshRequest(refreshToken));
            refreshToken = (await refreshed.ReadSuccessAsync<AuthTokenPair>()).RefreshToken;
        }

        for (var index = 0; index < 2; index++)
        {
            await client.PostAsJsonAsync("/api/v1/auth/login", new LoginRequest(ApiScenario.NewEmail(), "x"));
        }

        var limited = await client.PostAsJsonAsync("/api/v1/auth/login", new LoginRequest(ApiScenario.NewEmail(), "x"));
        Assert.Equal(HttpStatusCode.TooManyRequests, limited.StatusCode);
        Assert.True(limited.Headers.Contains("Retry-After"));
    }

    [Fact]
    public async Task Refresh_token_cannot_be_reused_after_rotation()
    {
        var session = await fixture.Api.RegisterAsync();
        var client = fixture.Api.Anonymous();

        var first = await client.PostAsJsonAsync("/api/v1/auth/refresh", new RefreshRequest(session.Tokens.RefreshToken));
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);

        var reused = await client.PostAsJsonAsync("/api/v1/auth/refresh", new RefreshRequest(session.Tokens.RefreshToken));
        Assert.Equal(HttpStatusCode.Unauthorized, reused.StatusCode);
    }

    [Fact]
    public async Task Register_and_create_class_rejects_an_invalid_school_year_with_a_400()
    {
        var response = await fixture.Api.Anonymous().PostAsJsonAsync("/api/v1/auth/register-and-create-class",
            new RegisterAndCreateClassRequest(ApiScenario.NewEmail(), ApiScenario.Password, "Nina", "Durand", ApiScenario.NewClassName(), "2026"));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Register_and_create_class_rejects_a_duplicate_class_name_with_a_409()
    {
        var className = ApiScenario.NewClassName();
        var client = fixture.Api.Anonymous();
        var first = await client.PostAsJsonAsync("/api/v1/auth/register-and-create-class",
            new RegisterAndCreateClassRequest(ApiScenario.NewEmail(), ApiScenario.Password, "Nina", "Durand", className, "2026-2027"));
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);

        var duplicate = await client.PostAsJsonAsync("/api/v1/auth/register-and-create-class",
            new RegisterAndCreateClassRequest(ApiScenario.NewEmail(), ApiScenario.Password, "Nina", "Durand", className, "2026-2027"));
        Assert.Equal(HttpStatusCode.Conflict, duplicate.StatusCode);
    }
}
