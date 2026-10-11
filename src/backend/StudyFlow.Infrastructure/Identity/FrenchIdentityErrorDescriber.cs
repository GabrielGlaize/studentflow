using Microsoft.AspNetCore.Identity;

namespace StudyFlow.Infrastructure.Identity;

/// <summary>Messages d'Identity affichés tels quels dans l'app : en français, et dans le même ton.</summary>
public sealed class FrenchIdentityErrorDescriber : IdentityErrorDescriber
{
    public override IdentityError DuplicateEmail(string email) => new()
    {
        Code = nameof(DuplicateEmail),
        Description = "Un compte existe déjà avec cette adresse e-mail. Connecte-toi ou utilise « Mot de passe oublié ? »."
    };

    // L'identifiant est l'adresse e-mail : même message que ci-dessus, sans doublon.
    public override IdentityError DuplicateUserName(string userName) => DuplicateEmail(userName);

    public override IdentityError InvalidEmail(string? email) => new()
    {
        Code = nameof(InvalidEmail),
        Description = "Adresse e-mail invalide."
    };

    public override IdentityError InvalidUserName(string? userName) => InvalidEmail(userName);

    public override IdentityError PasswordTooShort(int length) => new()
    {
        Code = nameof(PasswordTooShort),
        Description = $"Le mot de passe doit contenir au moins {length} caractères."
    };

    public override IdentityError PasswordRequiresDigit() => new()
    {
        Code = nameof(PasswordRequiresDigit),
        Description = "Le mot de passe doit contenir au moins un chiffre."
    };

    public override IdentityError PasswordRequiresLower() => new()
    {
        Code = nameof(PasswordRequiresLower),
        Description = "Le mot de passe doit contenir au moins une minuscule."
    };

    public override IdentityError PasswordRequiresUpper() => new()
    {
        Code = nameof(PasswordRequiresUpper),
        Description = "Le mot de passe doit contenir au moins une majuscule."
    };

    public override IdentityError PasswordRequiresNonAlphanumeric() => new()
    {
        Code = nameof(PasswordRequiresNonAlphanumeric),
        Description = "Le mot de passe doit contenir au moins un caractère spécial (! ? @ # …)."
    };

    public override IdentityError PasswordRequiresUniqueChars(int uniqueChars) => new()
    {
        Code = nameof(PasswordRequiresUniqueChars),
        Description = $"Le mot de passe doit contenir au moins {uniqueChars} caractères différents."
    };
}
