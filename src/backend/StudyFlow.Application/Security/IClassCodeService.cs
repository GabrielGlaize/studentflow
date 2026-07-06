namespace StudyFlow.Application.Security;

public sealed record GeneratedClassCode(string Plaintext, string Hash, string Ciphertext);

public interface IClassCodeService
{
    GeneratedClassCode Generate();
    string ComputeHash(string code);
    string Reveal(string ciphertext);
}
