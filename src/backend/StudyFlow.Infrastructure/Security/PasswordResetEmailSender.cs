using System.Net;
using System.Net.Mail;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using StudyFlow.Application.Security;

namespace StudyFlow.Infrastructure.Security;

public sealed class PasswordResetEmailSender(
    IOptions<EmailOptions> options,
    IHostEnvironment environment,
    ILogger<PasswordResetEmailSender> logger) : IPasswordResetEmailSender
{
    private readonly EmailOptions _options = options.Value;

    public async Task SendPasswordResetAsync(
        string email,
        string resetToken,
        DateTimeOffset expiresAt,
        CancellationToken cancellationToken = default)
    {
        if (!_options.IsSmtpConfigured)
        {
            // Hors développement, un code écrit dans les journaux permettrait à quiconque
            // y a accès de prendre le contrôle du compte.
            if (environment.IsDevelopment())
            {
                logger.LogInformation(
                    "SMTP is not configured. Password reset code for {Email}: {ResetToken}",
                    email,
                    resetToken);
            }
            else
            {
                logger.LogWarning("SMTP is not configured: the password reset e-mail was not sent.");
            }

            return;
        }

        using var message = new MailMessage(
            from: _options.From,
            to: email,
            subject: "Réinitialisation de ton mot de passe Swikko",
            body: BuildBody(resetToken, expiresAt));

        using var client = new SmtpClient(_options.Host, _options.Port)
        {
            EnableSsl = _options.UseSsl
        };

        if (!string.IsNullOrWhiteSpace(_options.UserName))
        {
            client.Credentials = new NetworkCredential(_options.UserName, _options.Password);
        }

        using var registration = cancellationToken.Register(client.SendAsyncCancel);
        await client.SendMailAsync(message, cancellationToken);
    }

    private string BuildBody(string resetCode, DateTimeOffset expiresAt)
    {
        // Heure de l'école (Paris), pas l'heure UTC du serveur.
        var localExpiry = TimeZoneInfo.ConvertTime(expiresAt, ParisTimeZone);
        var resetLink = string.IsNullOrWhiteSpace(_options.PasswordResetUrlBase)
            ? null
            : $"{_options.PasswordResetUrlBase.TrimEnd('/')}?token={Uri.EscapeDataString(resetCode)}";

        return $"""
            Bonjour,

            Voici ton code pour choisir un nouveau mot de passe Swikko :

                {resetCode}

            Dans l'app : « Mot de passe oublié ? », puis saisis ce code et ton nouveau mot de passe.
            {(resetLink is null ? "" : $"Lien direct : {resetLink}\n")}
            Il est valable jusqu'au {localExpiry:dd/MM/yyyy à HH:mm}.
            Si tu n'es pas à l'origine de cette demande, ignore cet e-mail : ton mot de passe ne change pas.

            L'équipe Swikko
            """;
    }

    private static readonly TimeZoneInfo ParisTimeZone =
        TimeZoneInfo.TryFindSystemTimeZoneById("Europe/Paris", out var zone) ? zone : TimeZoneInfo.Utc;
}
