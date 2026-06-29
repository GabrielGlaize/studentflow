import 'package:studyflow_app/core/network/api_client.dart';
import 'package:studyflow_app/features/profile/data/notification_preferences_repository.dart';
import 'package:studyflow_app/features/profile/domain/notification_preferences.dart';

class HttpNotificationPreferencesRepository
    implements NotificationPreferencesRepository {
  const HttpNotificationPreferencesRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<NotificationPreferences> getPreferences({String? accessToken}) async {
    final json = await _apiClient.getJson(
      '/api/v1/notifications/preferences',
      accessToken: accessToken,
    );
    return NotificationPreferences.fromJson(json);
  }

  @override
  Future<NotificationPreferences> updatePreferences({
    required NotificationPreferences preferences,
    String? accessToken,
  }) async {
    final json = await _apiClient.putJson(
      '/api/v1/notifications/preferences',
      body: preferences.toJson(),
      accessToken: accessToken,
    );
    return NotificationPreferences.fromJson(json);
  }
}
