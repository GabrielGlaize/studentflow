import 'package:studyflow_app/features/profile/domain/notification_preferences.dart';

abstract interface class NotificationPreferencesRepository {
  Future<NotificationPreferences> getPreferences({String? accessToken});

  Future<NotificationPreferences> updatePreferences({
    required NotificationPreferences preferences,
    String? accessToken,
  });
}
