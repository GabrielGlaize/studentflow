enum AppFlavor { dev, prod }

class AppEnvironment {
  const AppEnvironment._({
    required this.flavor,
    required this.useDemoRepositoriesByDefault,
    this.productionApiBaseUrl,
  });

  /// Local development: the app talks to the local backend by default.
  const AppEnvironment.dev({bool useDemoRepositories = false})
    : this._(
        flavor: AppFlavor.dev,
        useDemoRepositoriesByDefault: useDemoRepositories,
      );

  /// Production build: no demo repositories, no local emulator URL.
  const AppEnvironment.prod({
    String productionApiBaseUrl = 'https://api.studyflow.app',
  }) : this._(
         flavor: AppFlavor.prod,
         useDemoRepositoriesByDefault: false,
         productionApiBaseUrl: productionApiBaseUrl,
       );

  final AppFlavor flavor;
  final bool useDemoRepositoriesByDefault;
  final String? productionApiBaseUrl;

  bool get isProd => flavor == AppFlavor.prod;
}
