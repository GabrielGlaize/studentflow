namespace StudyFlow.Infrastructure.Notifications;

public sealed class FirebaseOptions
{
    public const string SectionName = "Firebase";

    /// <summary>
    /// Fichier JSON du compte de service Firebase (Paramètres du projet > Comptes de service).
    /// Il donne le droit d'envoyer des notifications : il reste hors du dépôt Git.
    /// </summary>
    public string? CredentialsPath { get; set; }

    public bool IsConfigured => !string.IsNullOrWhiteSpace(CredentialsPath);
}
