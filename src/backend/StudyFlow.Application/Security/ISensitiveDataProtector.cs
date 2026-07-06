namespace StudyFlow.Application.Security;

public interface ISensitiveDataProtector
{
    string Protect(string plaintext, string purpose);
    string Unprotect(string ciphertext, string purpose);
    string ComputeLookupHash(string value, string purpose);
}
