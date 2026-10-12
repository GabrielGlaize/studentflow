namespace StudyFlow.Application.Security;

public interface ISensitiveDataProtector
{
    string Protect(string plaintext, string purpose);
    string Unprotect(string ciphertext, string purpose);
    byte[] ProtectBytes(byte[] plaintext, string purpose);
    byte[] UnprotectBytes(byte[] ciphertext, string purpose);
    string ComputeLookupHash(string value, string purpose);
}
