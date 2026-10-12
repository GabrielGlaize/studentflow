using System.Net;
using System.Net.Mail;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using StudyFlow.Application.Security;
using StudyFlow.Application.Support;

namespace StudyFlow.Infrastructure.Security;

/// <summary>E-mails de Swikko (code d'inscription, réinitialisation du mot de passe) par SMTP.</summary>
public sealed class SmtpEmailSender(
    IOptions<EmailOptions> options,
    IHostEnvironment environment,
    ILogger<SmtpEmailSender> logger) : IPasswordResetEmailSender, IEmailVerificationSender, IFeedbackNotifier
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
            LogUnsentCode("Password reset", email, resetToken);
            return;
        }

        await SendAsync(
            email,
            "Réinitialisation de ton mot de passe Swikko",
            BuildPasswordResetBody(resetToken, expiresAt),
            cancellationToken);
    }

    public async Task<bool> SendEmailVerificationAsync(
        string email,
        string code,
        DateTimeOffset expiresAt,
        CancellationToken cancellationToken = default)
    {
        if (!_options.IsSmtpConfigured)
        {
            LogUnsentCode("E-mail verification", email, code);
            // En développement, le code est renvoyé par l'API : l'inscription reste possible.
            return environment.IsDevelopment();
        }

        await SendAsync(
            email,
            $"{code} : ton code Swikko",
            BuildVerificationBody(code, expiresAt),
            cancellationToken);
        return true;
    }

    public async Task NotifyAsync(FeedbackMessage feedback, CancellationToken cancellationToken = default)
    {
        var recipient = !string.IsNullOrWhiteSpace(_options.FeedbackTo)
            ? _options.FeedbackTo
            : _options.UserName;
        if (!_options.IsSmtpConfigured || string.IsNullOrWhiteSpace(recipient))
        {
            logger.LogInformation("SMTP is not configured: feedback stored without e-mail.");
            return;
        }

        var label = feedback.Kind == "bug" ? "Bug" : "Idée";
        var firstLine = feedback.Message.Split('\n')[0];
        var summary = firstLine.Length <= 60 ? firstLine : $"{firstLine[..59]}…";
        await SendAsync(
            recipient,
            $"[Swikko] {label} : {summary}",
            $"""
            {label} remonté(e) depuis l'app.

            De : {feedback.AuthorName} <{feedback.AuthorEmail}>
            Version : {feedback.AppVersion ?? "?"} · {feedback.Platform ?? "?"}

            {feedback.Message}
            """,
            cancellationToken);
    }

    private void LogUnsentCode(string purpose, string email, string code)
    {
        // Hors développement, un code écrit dans les journaux permettrait à quiconque
        // y a accès de prendre le contrôle du compte.
        if (environment.IsDevelopment())
        {
            logger.LogInformation("SMTP is not configured. {Purpose} code for {Email}: {Code}", purpose, email, code);
        }
        else
        {
            logger.LogWarning("SMTP is not configured: the {Purpose} e-mail was not sent.", purpose);
        }
    }

    private async Task SendAsync(string email, string subject, string body, CancellationToken cancellationToken)
    {
        using var message = new MailMessage(from: _options.From, to: email, subject: subject, body: body);

        using var client = new SmtpClient(_options.Host, _options.Port)
        {
            EnableSsl = _options.UseSsl
        };

        if (!string.IsNullOrWhiteSpace(_options.UserName))
        {
            client.Credentials = new NetworkCredential(_options.UserName, _options.Password);
        }

        using var registration = cancellationToken.Register(client.SendAsyncCancel);
        try
        {
            await client.SendMailAsync(message, cancellationToken);
        }
        catch (SmtpException exception) when (environment.IsDevelopment())
        {
            // En dev, Mailpit peut ne pas tourner : le code est de toute façon renvoyé par l'API.
            logger.LogWarning(exception, "SMTP indisponible en développement ({Host}:{Port}) : e-mail « {Subject} » non envoyé.",
                _options.Host, _options.Port, subject);
        }
    }

    private static string BuildVerificationBody(string code, DateTimeOffset expiresAt)
    {
        var localExpiry = TimeZoneInfo.ConvertTime(expiresAt, ParisTimeZone);

        return $"""
            Bonjour,

            Voici ton code pour créer ton compte Swikko :

                {code}

            Saisis-le dans l'app pour confirmer ton adresse e-mail.
            Il est valable jusqu'à {localExpiry:HH:mm}.
            Si tu n'as pas demandé à créer de compte, ignore cet e-mail.

            L'équipe Swikko
            """;
    }

    private string BuildPasswordResetBody(string resetCode, DateTimeOffset expiresAt)
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
