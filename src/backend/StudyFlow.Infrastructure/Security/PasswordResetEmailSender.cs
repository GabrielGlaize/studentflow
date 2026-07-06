using System.Net;
using System.Net.Mail;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using StudyFlow.Application.Security;

namespace StudyFlow.Infrastructure.Security;

public sealed class PasswordResetEmailSender(
    IOptions<EmailOptions> options,
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
            logger.LogInformation(
                "SMTP is not configured. Password reset code for {Email}: {ResetToken}",
                email,
                resetToken);
            return;
        }

        using var message = new MailMessage(
            from: _options.From,
            to: email,
            subject: "Réinitialisation de ton mot de passe StudyFlow",
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

    private string BuildBody(string resetToken, DateTimeOffset expiresAt)
    {
        var resetLink = string.IsNullOrWhiteSpace(_options.PasswordResetUrlBase)
            ? null
            : $"{_options.PasswordResetUrlBase.TrimEnd('/')}?token={Uri.EscapeDataString(resetToken)}";

        return resetLink is null
            ? $"""
              Voici ton code de réinitialisation StudyFlow :

              {resetToken}

              Il expire le {expiresAt:dd/MM/yyyy à HH:mm}.
              Si tu n'es pas à l'origine de cette demande, ignore cet e-mail.
              """
            : $"""
              Voici ton code de réinitialisation StudyFlow :

              {resetToken}

              Lien direct : {resetLink}

              Il expire le {expiresAt:dd/MM/yyyy à HH:mm}.
              Si tu n'es pas à l'origine de cette demande, ignore cet e-mail.
              """;
    }
}
