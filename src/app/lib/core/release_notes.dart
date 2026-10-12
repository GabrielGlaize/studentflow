/// Notes de version montrées dans « Quoi de neuf » après chaque mise à jour,
/// et toutes ensemble dans Paramètres › Historique des mises à jour.
///
/// À chaque nouvelle version : ajouter une entrée EN TÊTE de [releases]
/// (nouveautés + correctifs) et monter `version:` dans pubspec.yaml. L'écran
/// s'affiche une fois, au premier lancement de la nouvelle version.
/// Voir la skill de déploiement (.claude/skills/deploy).
class AppRelease {
  const AppRelease({
    required this.version,
    required this.date,
    required this.title,
    required this.items,
    this.fixes = const [],
  });

  final String version;
  final String date;
  final String title;

  /// Nouveautés, une phrase chacune, du point de vue de l'élève.
  final List<String> items;

  /// Correctifs de bugs visibles par l'élève.
  final List<String> fixes;
}

abstract final class ReleaseNotes {
  static const releases = [
    AppRelease(
      version: '1.2.0',
      date: 'Octobre 2026',
      title: 'Le travail de groupe arrive',
      items: [
        'Crée un groupe privé avec tes camarades, lié à un devoir ou à un cours : seuls ses membres le voient.',
        'Discussion en direct, avec « … écrit » et « vu ». Tout est chiffré sur le serveur.',
        'Répartissez les tâches : chacun sait quoi faire et pour quand, et retrouve les siennes dans son agenda.',
        'Swikko trouve les créneaux où tout le monde est libre, en tenant compte des jours en entreprise.',
        'Proposez une réunion : quand tout le monde a dit oui, elle s’ajoute à l’agenda de chacun, avec un rappel.',
        'Un devoir peut être marqué « travail de groupe » : on voit qui a déjà un groupe et qui est encore seul.',
        'Paramètres › Historique des mises à jour : toutes les versions de Swikko.',
      ],
    ),
    AppRelease(
      version: '1.1.0',
      date: 'Octobre 2026',
      title: 'StudyFlow devient Swikko',
      items: [
        'Nouveau nom, nouveau logo : les deux flèches, c’est l’aller-retour école ⇄ entreprise.',
        'Partage l’app à tes camarades en un geste, avec le code de ta classe.',
        'Une idée ou un bug ? Envoie-le directement depuis Paramètres.',
        'Agenda en vue calendrier, notes rapides du jour, ne pas déranger.',
        'Annule toute une journée de cours en deux touches quand le prof est absent.',
        'Mot de passe oublié : un code arrive par e-mail.',
        'Une présentation de l’app pour les nouveaux comptes.',
      ],
      fixes: [
        'Le bouton « Suivant » de la présentation n’est plus caché par un message.',
        'Les numéros de ligne des notes sont alignés avec le texte.',
        'Rétablir un cours annulé fonctionne même si un camarade l’a modifié entre-temps.',
        'La carte de la classe se met à jour après une demande d’adhésion.',
      ],
    ),
    AppRelease(
      version: '1.0.2',
      date: 'Octobre 2026',
      title: 'Les partiels',
      items: [
        'Partiels : fiche de révision commune par matière, ouverte deux semaines avant.',
        'Choisis le moment de chaque rappel, devoir par devoir.',
        'Balaie le planning pour changer de jour ; vue semaine compacte.',
        'Cours plus rapides à saisir : répétition chaque semaine, duplication, plusieurs créneaux.',
        'Matières et intervenants : suppression multiple.',
        'Nouveau thème, avec un vrai mode sombre.',
      ],
      fixes: [
        'Les dates ne se décalent plus au changement d’heure.',
        'Un conflit entre deux cours est expliqué clairement.',
      ],
    ),
    AppRelease(
      version: '1.0.1',
      date: 'Octobre 2026',
      title: 'Les notifications',
      items: [
        'Rappels de cours et de devoirs, même quand l’app est fermée.',
        'Les annonces de la classe arrivent aussitôt sur ton téléphone.',
        'Supprime ton compte et tes données quand tu veux.',
      ],
      fixes: ['Plus de déconnexion quand le réseau coupe.'],
    ),
    AppRelease(
      version: '1.0.0',
      date: 'Juillet 2026',
      title: 'Première version',
      items: [
        'Rejoins ta classe avec un code, validé par le délégué.',
        'Planning et devoirs partagés : chacun peut compléter ou corriger.',
        'Agenda perso : tâches et événements visibles par toi seul.',
        'Recherche d’alternance, favoris et entraide de la classe.',
        'Espace Entreprise : documents, contacts et tâches.',
      ],
    ),
  ];

  static AppRelease get current => releases.first;
}
