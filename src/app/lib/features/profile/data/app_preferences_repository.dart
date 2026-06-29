import 'package:studyflow_app/features/profile/domain/app_preferences.dart';

abstract interface class AppPreferencesRepository {
  Future<RemoteAppPreferences> getPreferences({String? accessToken});

  Future<RemoteAppPreferences> updatePreferences({
    required RemoteAppPreferences preferences,
    String? accessToken,
  });
}
