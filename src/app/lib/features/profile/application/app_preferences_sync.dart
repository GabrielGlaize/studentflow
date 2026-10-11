import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/features/profile/domain/app_preferences.dart';

/// Thème et entreprise : gardés sur le téléphone et sauvegardés sur le serveur
/// (pour les retrouver sur un autre appareil). La version la plus récente
/// l'emporte, pour qu'un serveur vide ou en retard n'efface jamais l'entreprise
/// choisie sur le téléphone.
abstract final class AppPreferencesSync {
  /// À l'ouverture du profil : reprend la version du serveur si elle est plus
  /// récente, sinon lui envoie celle du téléphone.
  static Future<void> reconcile(AppScope appScope) async {
    final settings = appScope.settingsController;
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      final remote = await appScope.appPreferencesRepository.getPreferences(
        accessToken: accessToken,
      );

      final remoteStamp = remote.updatedAt;
      final localStamp = settings.appPreferencesUpdatedAt;
      final serverIsNewer =
          remoteStamp != null &&
          (localStamp == null || remoteStamp.isAfter(localStamp));

      if (serverIsNewer) {
        settings.applyAppPreferences(
          themeMode: remote.themeMode,
          hasCompany: remote.hasCompany,
          companyName: remote.companyName,
          updatedAt: remoteStamp,
        );
      } else if (!_sameAsLocal(remote, appScope)) {
        await push(appScope);
      }
    } on Exception {
      // Hors connexion : les réglages du téléphone restent utilisables.
    }
  }

  /// Envoie au serveur les réglages actuels du téléphone.
  static Future<void> push(AppScope appScope) async {
    final settings = appScope.settingsController;
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      final saved = await appScope.appPreferencesRepository.updatePreferences(
        preferences: RemoteAppPreferences(
          themeMode: settings.themeMode,
          hasCompany: settings.hasCompany,
          companyName: settings.companyName,
          professionalMode: settings.hasCompany
              ? ProfessionalMode.company
              : ProfessionalMode.apprenticeship,
        ),
        accessToken: accessToken,
      );
      settings.markAppPreferencesSynced(saved.updatedAt);
    } on Exception {
      // Le réglage est déjà gardé sur le téléphone ; il repartira à la
      // prochaine ouverture du profil.
    }
  }

  static bool _sameAsLocal(RemoteAppPreferences remote, AppScope appScope) {
    final settings = appScope.settingsController;
    return remote.updatedAt != null &&
        remote.themeMode == settings.themeMode &&
        remote.hasCompany == settings.hasCompany &&
        (remote.companyName ?? '') == (settings.companyName ?? '');
  }
}
