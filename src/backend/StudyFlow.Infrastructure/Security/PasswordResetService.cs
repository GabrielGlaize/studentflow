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

public sealed class PasswordResetService(
    StudyFlowDbContext dbContext,
    UserManager<ApplicationUser> userManager,
    IWebHostEnvironment environment,
    IOptions<SecurityOptions> securityOptions,
    IPasswordResetEmailSender emailSender,
    ILogger<PasswordResetService> logger) : IPasswordResetService
{
    /// <summary>
    /// Code court à taper sur le téléphone : 8 caractères sans ambiguïté (ni 0/O,
    /// ni 1/I/L), soit ~8·10¹¹ possibilités. Avec la limite de requêtes et
    /// <see cref="MaxFailedAttempts"/> essais par code, il ne se devine pas.
    /// </summary>
    private const string CodeAlphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
    private const int CodeLength = 8;
    private const int MaxFailedAttempts = 5;
    private readonly SecurityOptions _securityOptions = securityOptions.Value;

    public async Task<PasswordResetRequestResult> RequestResetAsync(
        string email,
        CancellationToken cancellationToken = default)
    {
        var user = await userManager.FindByEmailAsync(email.Trim());

        // Same public behavior for existing and unknown accounts: this prevents
        // account enumeration through the reset endpoint.
        if (user is null || !user.IsActive)
        {
            return new PasswordResetRequestResult(IsAccepted: true);
        }

        var now = DateTimeOffset.UtcNow;
        var rawToken = RandomNumberGenerator.GetString(CodeAlphabet, CodeLength);
        var token = new PasswordResetToken
        {
            UserId = user.Id,
            TokenHash = HashToken(rawToken),
            CreatedAt = now,
            ExpiresAt = now.AddMinutes(_securityOptions.PasswordResetTokenMinutes)
        };

        // Keep only the latest active reset token for this user.
        var previousTokens = await dbContext.PasswordResetTokens
            .Where(x => x.UserId == user.Id && x.UsedAt == null && x.RevokedAt == null && x.ExpiresAt > now)
            .ToListAsync(cancellationToken);
        foreach (var previousToken in previousTokens)
        {
            previousToken.RevokedAt = now;
        }

        dbContext.PasswordResetTokens.Add(token);
        await dbContext.SaveChangesAsync(cancellationToken);

        logger.LogInformation("Password reset token generated for user {UserId}.", user.Id);

        await emailSender.SendPasswordResetAsync(
            user.Email ?? email.Trim(),
            FormatCode(rawToken),
            token.ExpiresAt,
            cancellationToken);

        return new PasswordResetRequestResult(
            IsAccepted: true,
            DevelopmentToken: environment.IsDevelopment() ? FormatCode(rawToken) : null,
            ExpiresAt: token.ExpiresAt);
    }

    public async Task<bool> ResetPasswordAsync(
        string email,
        string resetToken,
        string newPassword,
        CancellationToken cancellationToken = default)
    {
        var user = await userManager.FindByEmailAsync(email.Trim());
        if (user is null || !user.IsActive) return false;

        var tokenHash = HashToken(NormalizeCode(resetToken));
        var now = DateTimeOffset.UtcNow;
        // Un seul code actif par compte : le dernier demandé.
        var storedToken = await dbContext.PasswordResetTokens
            .Where(x => x.UserId == user.Id
                && x.UsedAt == null
                && x.RevokedAt == null
                && x.ExpiresAt > now)
            .OrderByDescending(x => x.CreatedAt)
            .FirstOrDefaultAsync(cancellationToken);
        if (storedToken is null) return false;

        if (!CryptographicOperations.FixedTimeEquals(
                Encoding.ASCII.GetBytes(storedToken.TokenHash),
                Encoding.ASCII.GetBytes(tokenHash)))
        {
            storedToken.FailedAttempts++;
            if (storedToken.FailedAttempts >= MaxFailedAttempts) storedToken.RevokedAt = now;
            await dbContext.SaveChangesAsync(cancellationToken);
            return false;
        }

        var identityToken = await userManager.GeneratePasswordResetTokenAsync(user);
        var result = await userManager.ResetPasswordAsync(user, identityToken, newPassword);
        if (!result.Succeeded) return false;

        storedToken.UsedAt = now;

        var otherActiveTokens = await dbContext.PasswordResetTokens
            .Where(x => x.UserId == user.Id && x.Id != storedToken.Id && x.UsedAt == null && x.RevokedAt == null)
            .ToListAsync(cancellationToken);
        foreach (var otherToken in otherActiveTokens)
        {
            otherToken.RevokedAt = now;
        }

        var activeRefreshTokens = await dbContext.RefreshTokens
            .Where(x => x.UserId == user.Id && x.RevokedAt == null && x.ExpiresAt > now)
            .ToListAsync(cancellationToken);
        foreach (var refreshToken in activeRefreshTokens)
        {
            refreshToken.RevokedAt = now;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }

    /// <summary>« abcd efgh », « ABCD-EFGH » : même code.</summary>
    private static string NormalizeCode(string code) =>
        new(code.Where(char.IsLetterOrDigit).Select(char.ToUpperInvariant).ToArray());

    /// <summary>« ABCDEFGH » → « ABCD-EFGH », plus lisible dans l'e-mail.</summary>
    private static string FormatCode(string code) =>
        code.Length == CodeLength ? $"{code[..4]}-{code[4..]}" : code;

    private string HashToken(string token)
    {
        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(_securityOptions.LookupKey));
        return Convert.ToHexString(hmac.ComputeHash(Encoding.UTF8.GetBytes($"password-reset:{token.Trim()}")))
            .ToLowerInvariant();
    }
}
