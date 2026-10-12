/// Notes de version montrées dans « Quoi de neuf » après chaque mise à jour.
///
/// À chaque nouvelle version : ajouter une entrée EN TÊTE de [releases] et
/// monter `version:` dans pubspec.yaml. L'écran s'affiche une fois, au
/// premier lancement de la nouvelle version.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.date,
    required this.title,
    required this.items,
  });

  final String version;
  final String date;
  final String title;
  final List<String> items;
}

abstract final class ReleaseNotes {
  static const releases = [
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
      ],
    ),
  ];

  static AppRelease get current => releases.first;
}
