using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.Extensions.Options;
using StudyFlow.Application.Security;

namespace StudyFlow.Infrastructure.Security;

public sealed class SensitiveDataProtector(
    IDataProtectionProvider dataProtectionProvider,
    IOptions<SecurityOptions> options) : ISensitiveDataProtector
{
    private readonly byte[] _lookupKey = Encoding.UTF8.GetBytes(options.Value.LookupKey);

    public string Protect(string plaintext, string purpose)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(plaintext);
        return CreateProtector(purpose).Protect(plaintext);
    }

    public string Unprotect(string ciphertext, string purpose)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(ciphertext);
        return CreateProtector(purpose).Unprotect(ciphertext);
    }

    public string ComputeLookupHash(string value, string purpose)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(value);
        using var hmac = new HMACSHA256(_lookupKey);
        var normalized = $"{purpose}:{value.Trim().ToUpperInvariant()}";
        return Convert.ToHexString(hmac.ComputeHash(Encoding.UTF8.GetBytes(normalized))).ToLowerInvariant();
    }

    private IDataProtector CreateProtector(string purpose) =>
        dataProtectionProvider.CreateProtector($"StudyFlow:{purpose}:v1");
}
