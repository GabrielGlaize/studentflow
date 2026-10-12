import 'package:flutter/foundation.dart';
import 'package:studyflow_app/core/config/app_environment.dart';

/// Centralise l'adresse de l'API.
abstract final class ApiConfig {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'STUDYFLOW_API_URL',
    defaultValue: '',
  );

  /// URL de l'API pour cet environnement. `STUDYFLOW_API_URL` (fichier de
  /// config ou script d'installation) l'emporte toujours.
  ///
  /// En dev sans URL : l'émulateur Android joint le Mac par `10.0.2.2`, les
  /// autres cibles locales par `localhost`.
  static String baseUrlFor(AppEnvironment environment) {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
    if (environment.isProd) return AppEnvironment.defaultProductionApiUrl;

    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:5028'
        : 'http://localhost:5028';
  }
}
