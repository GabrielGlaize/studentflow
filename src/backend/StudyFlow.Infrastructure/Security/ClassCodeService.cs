using System.Security.Cryptography;
using StudyFlow.Application.Security;

namespace StudyFlow.Infrastructure.Security;

public sealed class ClassCodeService(ISensitiveDataProtector protector) : IClassCodeService
{
    private const string Alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    private const string Purpose = "class-code";

    public GeneratedClassCode Generate()
    {
        Span<char> characters = stackalloc char[8];
        for (var index = 0; index < characters.Length; index++)
        {
            characters[index] = Alphabet[RandomNumberGenerator.GetInt32(Alphabet.Length)];
        }

        var normalized = new string(characters);
        var displayValue = $"{normalized[..4]}-{normalized[4..]}";
        return new GeneratedClassCode(
            displayValue,
            protector.ComputeLookupHash(normalized, Purpose),
            protector.Protect(displayValue, Purpose));
    }

    public string ComputeHash(string code) =>
        protector.ComputeLookupHash(Normalize(code), Purpose);

    public string Reveal(string ciphertext) => protector.Unprotect(ciphertext, Purpose);

    private static string Normalize(string code) =>
        new(code.Where(char.IsLetterOrDigit).Select(char.ToUpperInvariant).ToArray());
}
