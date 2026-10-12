import 'package:studyflow_app/core/config/app_environment.dart';
import 'package:studyflow_app/main.dart';

/// Point d'entrée forcé en production. On préfère
/// `flutter run --dart-define-from-file=config/prod.json` (voir config/README.md).
void main() {
  runStudyFlowApp(const AppEnvironment.prod());
}
