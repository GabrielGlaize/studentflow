using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using StudyFlow.Application.Security;
using StudyFlow.Infrastructure.Identity;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Infrastructure.Security;

public sealed class EmailVerificationService(
    StudyFlowDbContext dbContext,
    UserManager<ApplicationUser> userManager,
    IWebHostEnvironment environment,
    IOptions<SecurityOptions> securityOptions,
    IEmailVerificationSender emailSender,
    ILogger<EmailVerificationService> logger) : IEmailVerificationService
{
    /// <summary>
    /// 6 chiffres, faciles à taper ou à coller depuis l'e-mail. Avec la limite de requêtes,
    /// <see cref="MaxFailedAttempts"/> essais par code et l'expiration, il ne se devine pas.
    /// </summary>
    private const int CodeLength = 6;
    private const int MaxFailedAttempts = 5;

    /// <summary>Un nouveau code au plus par minute et par adresse : évite d'inonder une boîte.</summary>
    private static readonly TimeSpan ResendDelay = TimeSpan.FromSeconds(60);

    private readonly SecurityOptions _securityOptions = securityOptions.Value;

    public bool IsRequired => _securityOptions.RequireEmailVerification;

    public async Task<EmailVerificationRequestResult> RequestCodeAsync(
        string email,
        CancellationToken cancellationToken = default)
    {
        var trimmedEmail = email.Trim();
        if (await userManager.FindByEmailAsync(trimmedEmail) is not null)
        {
            return new EmailVerificationRequestResult(EmailVerificationRequestStatus.AlreadyRegistered);
        }

        var normalizedEmail = Normalize(trimmedEmail);
        var now = DateTimeOffset.UtcNow;
        var activeCodes = await ActiveCodes(normalizedEmail, now).ToListAsync(cancellationToken);
        if (activeCodes.Any(x => now - x.CreatedAt < ResendDelay))
        {
            return new EmailVerificationRequestResult(EmailVerificationRequestStatus.TooSoon);
        }

        var rawCode = string.Concat(Enumerable.Range(0, CodeLength)
            .Select(_ => (char)('0' + RandomNumberGenerator.GetInt32(10))));
        var code = new EmailVerificationCode
        {
            Email = normalizedEmail,
            CodeHash = HashCode(normalizedEmail, rawCode),
            CreatedAt = now,
            ExpiresAt = now.AddMinutes(_securityOptions.EmailVerificationCodeMinutes)
        };

        // Seul le dernier code demandé reste valable ; les vieux codes ne servent plus à rien.
        foreach (var previousCode in activeCodes) previousCode.RevokedAt = now;
        await dbContext.EmailVerificationCodes
            .Where(x => x.Email == normalizedEmail && x.ExpiresAt < now.AddDays(-1))
            .ExecuteDeleteAsync(cancellationToken);

        dbContext.EmailVerificationCodes.Add(code);
        await dbContext.SaveChangesAsync(cancellationToken);

        if (!await emailSender.SendEmailVerificationAsync(trimmedEmail, rawCode, code.ExpiresAt, cancellationToken))
        {
            code.RevokedAt = now;
            await dbContext.SaveChangesAsync(cancellationToken);
            return new EmailVerificationRequestResult(EmailVerificationRequestStatus.EmailUnavailable);
        }

        logger.LogInformation("E-mail verification code sent.");
        return new EmailVerificationRequestResult(
            EmailVerificationRequestStatus.Sent,
            environment.IsDevelopment() ? rawCode : null,
            code.ExpiresAt);
    }

    public async Task<bool> CheckCodeAsync(
        string email,
        string? code,
        CancellationToken cancellationToken = default)
    {
        var normalizedEmail = Normalize(email.Trim());
        var storedCode = await LatestActiveCodeAsync(normalizedEmail, cancellationToken);
        if (storedCode is null) return false;

        var typedCode = new string((code ?? "").Where(char.IsDigit).ToArray());
        if (CryptographicOperations.FixedTimeEquals(
                Encoding.ASCII.GetBytes(storedCode.CodeHash),
                Encoding.ASCII.GetBytes(HashCode(normalizedEmail, typedCode))))
        {
            return true;
        }

        storedCode.FailedAttempts++;
        if (storedCode.FailedAttempts >= MaxFailedAttempts) storedCode.RevokedAt = DateTimeOffset.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
        return false;
    }

    public async Task ConsumeCodeAsync(string email, CancellationToken cancellationToken = default)
    {
        var storedCode = await LatestActiveCodeAsync(Normalize(email.Trim()), cancellationToken);
        if (storedCode is not null) storedCode.UsedAt = DateTimeOffset.UtcNow;
    }

    private IQueryable<EmailVerificationCode> ActiveCodes(string normalizedEmail, DateTimeOffset now) =>
        dbContext.EmailVerificationCodes.Where(x => x.Email == normalizedEmail
            && x.UsedAt == null
            && x.RevokedAt == null
            && x.ExpiresAt > now);

    private Task<EmailVerificationCode?> LatestActiveCodeAsync(string normalizedEmail, CancellationToken cancellationToken) =>
        ActiveCodes(normalizedEmail, DateTimeOffset.UtcNow)
            .OrderByDescending(x => x.CreatedAt)
            .FirstOrDefaultAsync(cancellationToken);

    private string Normalize(string email) => userManager.NormalizeEmail(email) ?? email.ToUpperInvariant();

    /// <summary>L'adresse entre dans le hachage : deux adresses peuvent recevoir le même code.</summary>
    private string HashCode(string normalizedEmail, string code)
    {
        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(_securityOptions.LookupKey));
        return Convert.ToHexString(hmac.ComputeHash(Encoding.UTF8.GetBytes($"email-verification:{normalizedEmail}:{code}")))
            .ToLowerInvariant();
    }
}
