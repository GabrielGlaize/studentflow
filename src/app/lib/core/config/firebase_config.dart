import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Identifiants Firebase passés au build, par exemple :
/// `flutter run --dart-define-from-file=firebase_config.json`.
///
/// Sans eux, l'application fonctionne normalement mais ne reçoit pas de
/// notifications push. Seul Android est branché pour l'instant : iOS demande
/// une clé APNs (compte Apple Developer) et le Web un service worker.
abstract final class FirebaseConfig {
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const _messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  static FirebaseOptions? get currentPlatform {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    if ([
      _apiKey,
      _androidAppId,
      _messagingSenderId,
      _projectId,
    ].any((value) => value.isEmpty)) {
      return null;
    }

    return const FirebaseOptions(
      apiKey: _apiKey,
      appId: _androidAppId,
      messagingSenderId: _messagingSenderId,
      projectId: _projectId,
    );
  }
}
