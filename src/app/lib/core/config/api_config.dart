import 'package:flutter/foundation.dart';
import 'package:studyflow_app/core/config/app_environment.dart';

/// Centralizes API-related configuration.
abstract final class ApiConfig {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'STUDYFLOW_API_URL',
    defaultValue: '',
  );

  /// Default backend URL used by the selected app environment.
  ///
  /// Android emulators cannot reach the Mac with `localhost`; they use the
  /// special host `10.0.2.2`. Other local targets can keep `localhost`.
  static String baseUrlFor(AppEnvironment environment) {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
    if (environment.isProd) return environment.productionApiBaseUrl!;

    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:5028'
        : 'http://localhost:5028';
  }
}
