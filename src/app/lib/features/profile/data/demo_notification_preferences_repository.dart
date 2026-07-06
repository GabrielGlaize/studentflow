import 'package:studyflow_app/features/profile/data/notification_preferences_repository.dart';
import 'package:studyflow_app/features/profile/domain/notification_preferences.dart';

class DemoNotificationPreferencesRepository
    implements NotificationPreferencesRepository {
  const DemoNotificationPreferencesRepository();

  static NotificationPreferences _preferences = const NotificationPreferences(
    coursesEnabled: true,
    homeworkEnabled: true,
    apprenticeshipsEnabled: true,
    courseReminderMinutes: 5,
  );

  @override
  Future<NotificationPreferences> getPreferences({String? accessToken}) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return _preferences;
  }

  @override
  Future<NotificationPreferences> updatePreferences({
    required NotificationPreferences preferences,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _preferences = preferences;
    return _preferences;
  }
}
