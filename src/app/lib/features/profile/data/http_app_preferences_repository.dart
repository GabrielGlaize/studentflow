import 'package:studyflow_app/core/network/api_client.dart';
import 'package:studyflow_app/features/profile/data/app_preferences_repository.dart';
import 'package:studyflow_app/features/profile/domain/app_preferences.dart';

class HttpAppPreferencesRepository implements AppPreferencesRepository {
  const HttpAppPreferencesRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<RemoteAppPreferences> getPreferences({String? accessToken}) async {
    final json = await _apiClient.getJson(
      '/api/v1/profile',
      accessToken: accessToken,
    );
    return RemoteAppPreferences.fromJson(
      json['appSettings'] as Map<String, Object?>,
    );
  }

  @override
  Future<RemoteAppPreferences> updatePreferences({
    required RemoteAppPreferences preferences,
    String? accessToken,
  }) async {
    final json = await _apiClient.putJson(
      '/api/v1/profile/app-settings',
      body: preferences.toJson(),
      accessToken: accessToken,
    );
    return RemoteAppPreferences.fromJson(json);
  }
}
