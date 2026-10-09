namespace StudyFlow.Application.Exams;

/// <summary>
/// Règles des liens partagés dans les fiches de révision. Le serveur ne visite jamais le lien :
/// on vérifie seulement qu'il est en https et qu'il ne pointe pas directement vers un
/// exécutable ou une archive.
/// </summary>
public static class RevisionLinkPolicy
{
    public const int MaxLength = 2000;

    public static RevisionLinkCheck Check(string? value)
    {
        var text = value?.Trim() ?? string.Empty;
        if (text.Length == 0) return RevisionLinkCheck.Refused("Colle le lien à partager.");
        if (text.Length > MaxLength) return RevisionLinkCheck.Refused("Ce lien est trop long.");

        if (!Uri.TryCreate(text, UriKind.Absolute, out var uri))
        {
            return RevisionLinkCheck.Refused("Ce lien n'est pas valide. Il doit commencer par https://");
        }

        if (uri.Scheme == Uri.UriSchemeHttp)
        {
            return RevisionLinkCheck.Refused("Utilise un lien sécurisé, qui commence par https://");
        }

        if (uri.Scheme != Uri.UriSchemeHttps)
        {
            return RevisionLinkCheck.Refused("Seuls les liens web (https://) sont acceptés.");
        }

        if (!string.IsNullOrEmpty(uri.UserInfo))
        {
            return RevisionLinkCheck.Refused("Un lien ne doit pas contenir d'identifiant ni de mot de passe.");
        }

        if (uri.HostNameType != UriHostNameType.Dns || !uri.Host.Contains('.'))
        {
            return RevisionLinkCheck.Refused("Ce lien ne mène pas à un site web.");
        }

        var extension = Path.GetExtension(uri.AbsolutePath).ToLowerInvariant();
        if (RevisionFilePolicy.IsBlockedExtension(extension))
        {
            return RevisionLinkCheck.Refused(
                $"Ce lien télécharge un fichier {extension} : c'est interdit pour la sécurité de la classe.");
        }

        return new RevisionLinkCheck(true, null, uri.AbsoluteUri, uri.Host);
    }
}

public sealed record RevisionLinkCheck(bool IsAccepted, string? Error, string? NormalizedUrl, string? Host)
{
    public static RevisionLinkCheck Refused(string error) => new(false, error, null, null);
}
