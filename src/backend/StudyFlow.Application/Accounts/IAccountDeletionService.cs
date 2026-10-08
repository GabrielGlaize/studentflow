namespace StudyFlow.Application.Accounts;

public enum AccountDeletionResult
{
    Deleted,
    NotFound,

    /// <summary>Le compte est le dernier délégué d'une classe qui compte encore des membres.</summary>
    LastDelegate
}

public interface IAccountDeletionService
{
    /// <summary>
    /// Supprime les données personnelles du compte et anonymise ce qui doit rester
    /// pour la classe (cours, devoirs et annonces créés collectivement).
    /// </summary>
    Task<AccountDeletionResult> DeleteAsync(Guid userId, CancellationToken cancellationToken = default);
}
