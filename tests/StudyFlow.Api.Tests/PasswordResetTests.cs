using System.Collections.Concurrent;
using System.Net;
using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using StudyFlow.Api.Contracts;
using StudyFlow.Api.Tests.Infrastructure;
using StudyFlow.Application.Security;

namespace StudyFlow.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class PasswordResetTests(ApiFixture fixture)
{
    [Fact]
    public async Task A_short_emailed_code_resets_the_password()
    {
        var mailbox = new RecordingEmailSender();
        await using var api = fixture.CreateFactory(
            configureServices: services => services.AddSingleton<IPasswordResetEmailSender>(mailbox));
        var email = ApiScenario.NewEmail();
        await api.RegisterAsync(email);

        var requested = await api.Anonymous().PostAsJsonAsync("/api/v1/auth/forgot-password",
            new ForgotPasswordRequest(email));
        Assert.Equal(HttpStatusCode.OK, requested.StatusCode);
        var code = Assert.Single(mailbox.Codes);
        Assert.Matches("^[A-Z2-9]{4}-[A-Z2-9]{4}$", code);

        // Saisie tolérante : minuscules, sans tiret.
        var typed = code.Replace("-", " ").ToLowerInvariant();
        var reset = await api.Anonymous().PostAsJsonAsync("/api/v1/auth/reset-password",
            new ResetPasswordRequest(email, typed, "NouveauMotdepasse123!"));
        Assert.True(reset.IsSuccessStatusCode, await reset.Content.ReadAsStringAsync());

        var login = await api.Anonymous().PostAsJsonAsync("/api/v1/auth/login",
            new LoginRequest(email, "NouveauMotdepasse123!"));
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
    }

    [Fact]
    public async Task A_code_is_cancelled_after_five_wrong_attempts()
    {
        var mailbox = new RecordingEmailSender();
        await using var api = fixture.CreateFactory(
            configureServices: services => services.AddSingleton<IPasswordResetEmailSender>(mailbox));
        var email = ApiScenario.NewEmail();
        await api.RegisterAsync(email);
        await api.Anonymous().PostAsJsonAsync("/api/v1/auth/forgot-password", new ForgotPasswordRequest(email));
        var code = Assert.Single(mailbox.Codes);

        for (var attempt = 0; attempt < 5; attempt++)
        {
            var wrong = await api.Anonymous().PostAsJsonAsync("/api/v1/auth/reset-password",
                new ResetPasswordRequest(email, "ZZZZ-ZZZZ", "NouveauMotdepasse123!"));
            Assert.False(wrong.IsSuccessStatusCode);
        }

        // Même le bon code ne passe plus : il faut en redemander un.
        var late = await api.Anonymous().PostAsJsonAsync("/api/v1/auth/reset-password",
            new ResetPasswordRequest(email, code, "NouveauMotdepasse123!"));
        Assert.False(late.IsSuccessStatusCode);
    }

    private sealed class RecordingEmailSender : IPasswordResetEmailSender
    {
        public ConcurrentQueue<string> Codes { get; } = new();

        public Task SendPasswordResetAsync(
            string email,
            string resetToken,
            DateTimeOffset expiresAt,
            CancellationToken cancellationToken = default)
        {
            Codes.Enqueue(resetToken);
            return Task.CompletedTask;
        }
    }
}
