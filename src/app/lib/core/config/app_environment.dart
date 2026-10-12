/// Environnement de l'app, choisi à la compilation par `config/<env>.json`
/// (`--dart-define-from-file`) : voir config/README.md.
enum AppFlavor {
  /// API du Mac (`make dev`), bandeau « DEV ».
  dev('Développement'),

  /// API du NAS.
  prod('Production'),

  /// Sans serveur : données fictives intégrées à l'app.
  demo('Démonstration');

  const AppFlavor(this.label);

  final String label;
}

class AppEnvironment {
  const AppEnvironment._({
    required this.flavor,
    required this.useDemoRepositoriesByDefault,
  });

  /// Développement : l'app parle à l'API lancée sur le Mac.
  const AppEnvironment.dev({bool useDemoRepositories = false})
    : this._(
        flavor: AppFlavor.dev,
        useDemoRepositoriesByDefault: useDemoRepositories,
      );

  /// Production : l'API du NAS, jamais de données de démonstration.
  const AppEnvironment.prod()
    : this._(flavor: AppFlavor.prod, useDemoRepositoriesByDefault: false);

  /// Démonstration hors ligne (présentation, tests manuels sans serveur).
  const AppEnvironment.demo()
    : this._(flavor: AppFlavor.demo, useDemoRepositoriesByDefault: true);

  static const _configuredFlavor = String.fromEnvironment(
    'SWIKKO_ENV',
    defaultValue: 'dev',
  );

  /// L'environnement indiqué par `SWIKKO_ENV` (dev si rien n'est précisé).
  factory AppEnvironment.fromDefines() => switch (_configuredFlavor) {
    'prod' => const AppEnvironment.prod(),
    'demo' => const AppEnvironment.demo(),
    _ => const AppEnvironment.dev(),
  };

  /// API du NAS, si `config/prod.json` n'a pas été passé à la compilation.
  static const defaultProductionApiUrl = 'https://studyflow-dev.duckdns.org';

  final AppFlavor flavor;
  final bool useDemoRepositoriesByDefault;

  bool get isProd => flavor == AppFlavor.prod;

  /// L'app parle à l'API de dev du Mac (seedée) : bandeau « DEV » et comptes
  /// de test sur l'écran de connexion.
  bool get usesDevServer =>
      flavor == AppFlavor.dev && !useDemoRepositoriesByDefault;

  /// Bandeau « DEV » : on sait toujours qu'on n'est pas sur les vraies données.
  bool get showsDevBanner => usesDevServer;
}
