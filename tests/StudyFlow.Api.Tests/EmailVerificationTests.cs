using System.Collections.Concurrent;
using System.Net;
using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using StudyFlow.Api.Contracts;
using StudyFlow.Api.Tests.Infrastructure;
using StudyFlow.Application.Security;

namespace StudyFlow.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class EmailVerificationTests(ApiFixture fixture)
{
    [Fact]
    public async Task An_account_is_created_only_with_the_code_sent_to_the_address()
    {
        var mailbox = new RecordingSender();
        await using var api = CreateApi(mailbox);
        var client = api.Anonymous();
        var email = ApiScenario.NewEmail();

        var withoutCode = await client.PostAsJsonAsync("/api/v1/auth/register",
            new RegisterRequest(email, ApiScenario.Password, "Liam", "Martin"));
        Assert.Equal(HttpStatusCode.BadRequest, withoutCode.StatusCode);

        var sent = await client.PostAsJsonAsync("/api/v1/auth/email-verification", new EmailVerificationRequest(email));
        var response = await sent.ReadSuccessAsync<EmailVerificationResponse>();
        Assert.True(response.Required);
        var code = Assert.Single(mailbox.Codes);
        Assert.Matches("^[0-9]{6}$", code);

        var wrongCode = await client.PostAsJsonAsync("/api/v1/auth/register",
            new RegisterRequest(email, ApiScenario.Password, "Liam", "Martin", code == "000000" ? "111111" : "000000"));
        Assert.Equal(HttpStatusCode.BadRequest, wrongCode.StatusCode);

        // Un mot de passe refusé ne consomme pas le code : l'élève corrige et réessaie.
        var weakPassword = await client.PostAsJsonAsync("/api/v1/auth/register",
            new RegisterRequest(email, "court", "Liam", "Martin", code));
        Assert.Equal(HttpStatusCode.BadRequest, weakPassword.StatusCode);
        Assert.Contains("au moins 10 caractères", await weakPassword.Content.ReadAsStringAsync());

        var registered = await client.PostAsJsonAsync("/api/v1/auth/register",
            new RegisterRequest(email, ApiScenario.Password, "Liam", "Martin", code));
        await registered.ReadSuccessAsync<AuthResponse>();

        // Le code a servi : il ne permet pas un second compte, et l'adresse est maintenant prise.
        var again = await client.PostAsJsonAsync("/api/v1/auth/email-verification", new EmailVerificationRequest(email));
        Assert.Equal(HttpStatusCode.Conflict, again.StatusCode);
    }

    [Fact]
    public async Task Creating_a_class_also_requires_the_code()
    {
        var mailbox = new RecordingSender();
        await using var api = CreateApi(mailbox);
        var client = api.Anonymous();
        var email = ApiScenario.NewEmail("delegue");

        await client.PostAsJsonAsync("/api/v1/auth/email-verification", new EmailVerificationRequest(email));
        var code = Assert.Single(mailbox.Codes);

        var created = await client.PostAsJsonAsync("/api/v1/auth/register-and-create-class",
            new RegisterAndCreateClassRequest(email, ApiScenario.Password, "Gabriel", "Delegue",
                ApiScenario.NewClassName(), "2026-2027", code));
        var session = await created.ReadSuccessAsync<AuthResponse>();
        Assert.NotNull(session.ClassCode);
        Assert.NotNull(session.User.SchoolClassId);
    }

    [Fact]
    public async Task A_code_is_cancelled_after_five_wrong_attempts_and_resending_is_throttled()
    {
        var mailbox = new RecordingSender();
        await using var api = CreateApi(mailbox);
        var client = api.Anonymous();
        var email = ApiScenario.NewEmail();

        await client.PostAsJsonAsync("/api/v1/auth/email-verification", new EmailVerificationRequest(email));
        var code = Assert.Single(mailbox.Codes);

        var tooSoon = await client.PostAsJsonAsync("/api/v1/auth/email-verification", new EmailVerificationRequest(email));
        Assert.Equal(HttpStatusCode.TooManyRequests, tooSoon.StatusCode);
        Assert.Single(mailbox.Codes);

        var wrong = code == "000000" ? "111111" : "000000";
        for (var attempt = 0; attempt < 5; attempt++)
        {
            await client.PostAsJsonAsync("/api/v1/auth/register",
                new RegisterRequest(email, ApiScenario.Password, "Liam", "Martin", wrong));
        }

        var late = await client.PostAsJsonAsync("/api/v1/auth/register",
            new RegisterRequest(email, ApiScenario.Password, "Liam", "Martin", code));
        Assert.Equal(HttpStatusCode.BadRequest, late.StatusCode);
    }

    [Fact]
    public async Task Invalid_addresses_are_rejected_before_sending_anything()
    {
        var mailbox = new RecordingSender();
        await using var api = CreateApi(mailbox);

        var response = await api.Anonymous().PostAsJsonAsync("/api/v1/auth/email-verification",
            new EmailVerificationRequest("pas-une-adresse"));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Empty(mailbox.Codes);
    }

    private ApiFactory CreateApi(RecordingSender mailbox) => fixture.CreateFactory(
        new Dictionary<string, string?> { ["Security:RequireEmailVerification"] = "true" },
        services => services.AddSingleton<IEmailVerificationSender>(mailbox));

    private sealed class RecordingSender : IEmailVerificationSender
    {
        public ConcurrentQueue<string> Codes { get; } = new();

        public Task<bool> SendEmailVerificationAsync(
            string email,
            string code,
            DateTimeOffset expiresAt,
            CancellationToken cancellationToken = default)
        {
            Codes.Enqueue(code);
            return Task.FromResult(true);
        }
    }
}
