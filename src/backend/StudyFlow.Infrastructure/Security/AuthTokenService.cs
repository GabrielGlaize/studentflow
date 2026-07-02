using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using StudyFlow.Application.Security;
using StudyFlow.Infrastructure.Identity;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Infrastructure.Security;

public sealed class AuthTokenService(
    StudyFlowDbContext dbContext,
    UserManager<ApplicationUser> userManager,
    IOptions<JwtOptions> options,
    IOptions<SecurityOptions> securityOptions) : IAuthTokenService
{
    private const string SecurityStampClaimType = "sst";
    private readonly JwtOptions _options = options.Value;
    private readonly SecurityOptions _securityOptions = securityOptions.Value;

    public async Task<AuthTokenPair> IssueAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var user = await userManager.FindByIdAsync(userId.ToString())
            ?? throw new InvalidOperationException("User introuvable.");
        var pair = await CreatePairAsync(user, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        return pair;
    }

    public async Task<AuthTokenPair?> RotateAsync(string refreshToken, CancellationToken cancellationToken = default)
    {
        var tokenHash = Hash(refreshToken);
        var storedToken = await dbContext.RefreshTokens
            .Include(x => x.User)
            .SingleOrDefaultAsync(x => x.TokenHash == tokenHash, cancellationToken);

        if (storedToken is null || storedToken.RevokedAt is not null || storedToken.ExpiresAt <= DateTimeOffset.UtcNow || !storedToken.User.IsActive)
        {
            return null;
        }

        var pair = await CreatePairAsync(storedToken.User, cancellationToken);
        storedToken.RevokedAt = DateTimeOffset.UtcNow;
        storedToken.ReplacedByTokenHash = Hash(pair.RefreshToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        return pair;
    }

    public async Task<bool> RevokeAsync(Guid userId, string refreshToken, CancellationToken cancellationToken = default)
    {
        var tokenHash = Hash(refreshToken);
        var storedToken = await dbContext.RefreshTokens.SingleOrDefaultAsync(
            x => x.UserId == userId && x.TokenHash == tokenHash,
            cancellationToken);

        if (storedToken is null || storedToken.RevokedAt is not null)
        {
            return false;
        }

        storedToken.RevokedAt = DateTimeOffset.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }

    private async Task<AuthTokenPair> CreatePairAsync(ApplicationUser user, CancellationToken cancellationToken)
    {
        var now = DateTimeOffset.UtcNow;
        var accessExpiresAt = now.AddMinutes(_options.AccessTokenMinutes);
        var roles = await userManager.GetRolesAsync(user);
        var securityStamp = await userManager.GetSecurityStampAsync(user);
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            new(SecurityStampClaimType, securityStamp)
        };

        claims.AddRange(roles.Select(role => new Claim(ClaimTypes.Role, role)));

        var credentials = new SigningCredentials(
            new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_options.SigningKey)),
            SecurityAlgorithms.HmacSha256);
        var jwt = new JwtSecurityToken(
            _options.Issuer,
            _options.Audience,
            claims,
            now.UtcDateTime,
            accessExpiresAt.UtcDateTime,
            credentials);

        var rawRefreshToken = Base64UrlEncoder.Encode(RandomNumberGenerator.GetBytes(64));
        var refreshExpiresAt = now.AddDays(_options.RefreshTokenDays);
        dbContext.RefreshTokens.Add(new RefreshToken
        {
            UserId = user.Id,
            TokenHash = Hash(rawRefreshToken),
            CreatedAt = now,
            ExpiresAt = refreshExpiresAt
        });

        return new AuthTokenPair(
            new JwtSecurityTokenHandler().WriteToken(jwt),
            accessExpiresAt,
            rawRefreshToken,
            refreshExpiresAt);
    }

    private string Hash(string value)
    {
        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(_securityOptions.LookupKey));
        return Convert.ToHexString(hmac.ComputeHash(Encoding.UTF8.GetBytes($"refresh-token:{value.Trim()}")))
            .ToLowerInvariant();
    }
}
