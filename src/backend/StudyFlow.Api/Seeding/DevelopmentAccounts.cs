namespace StudyFlow.Api.Seeding;

/// <summary>Un compte de développement et la situation qu'il permet de tester.</summary>
/// <param name="InClass">Membre de la classe de dev ; sinon le compte n'a pas de classe.</param>
/// <param name="FirstLaunch">L'app ouvre la présentation après la connexion, comme pour un compte neuf.</param>
public sealed record DevelopmentAccount(
    string Key,
    string Email,
    string FirstName,
    string LastName,
    string Situation,
    string Details,
    bool InClass = true,
    bool IsDelegate = false,
    bool FirstLaunch = false);

/// <summary>
/// Les comptes du seed. Les trois premiers forment le scénario principal (le groupe de projet
/// de Gabriel) ; chacun des suivants teste une situation différente. L'écran de connexion de
/// l'app de dev les liste via <c>GET /api/v1/dev/accounts</c>.
/// </summary>
public static class DevelopmentAccounts
{
    public static readonly IReadOnlyList<DevelopmentAccount> All =
    [
        new("gabriel", "gabriel@studyflow.dev", "Gabriel", "Glaize",
            "Délégué, en entreprise",
            "Gère la classe, organise le projet BDD, 2 messages non lus, invité par Hugo.",
            IsDelegate: true),
        new("garance", "garance@studyflow.dev", "Garance", "Moreau",
            "Élève, en entreprise",
            "Dans le groupe de Gabriel, a proposé la réunion de jeudi."),
        new("liam", "liam@studyflow.dev", "Liam", "Petit",
            "Élève, en entreprise",
            "Dans le groupe de Gabriel, disponible le week-end."),
        new("ines", "ines@studyflow.dev", "Inès", "Benali",
            "Cherche son alternance",
            "Pas encore d'entreprise : l'onglet Alternances remplace Entreprise."),
        new("yanis", "yanis@studyflow.dev", "Yanis", "Kaci",
            "En retard sur ses devoirs",
            "Ses devoirs passés ne sont pas rendus, alors que le reste de la classe les a faits."),
        new("chloe", "chloe@studyflow.dev", "Chloé", "Durand",
            "Premier lancement",
            "La présentation de l'app s'ouvre après la connexion.",
            FirstLaunch: true),
        new("hugo", "hugo@studyflow.dev", "Hugo", "Lefèvre",
            "Attend une réponse à son invitation",
            "Seul dans son groupe « Dossier réseau », a invité Gabriel."),
        new("sarah", "sarah@studyflow.dev", "Sarah", "Fontaine",
            "Sans groupe pour deux travaux de groupe",
            "Projet BDD et dossier réseau : l'app lui propose de rejoindre ou créer un groupe."),
        new("nina", "nina@studyflow.dev", "Nina", "Lemoine",
            "Demande d'adhésion en attente",
            "A demandé à rejoindre la classe : Gabriel doit l'accepter.",
            InClass: false),
        new("tom", "tom@studyflow.dev", "Tom", "Garnier",
            "Sans classe",
            "Compte créé mais aucune classe : l'app lui propose d'en rejoindre ou d'en créer une.",
            InClass: false)
    ];

    public static DevelopmentAccount Get(string key) => All.Single(x => x.Key == key);
}
