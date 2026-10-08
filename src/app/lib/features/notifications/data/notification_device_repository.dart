import 'package:studyflow_app/core/network/api_client.dart';

/// Appareils qui reçoivent les notifications push du compte connecté.
abstract interface class NotificationDeviceRepository {
  /// Enregistre le jeton Firebase de l'appareil et renvoie l'identifiant
  /// de l'appareil côté API.
  Future<String> register({
    required String token,
    required String platform,
    String? accessToken,
  });

  Future<void> delete({required String deviceId, String? accessToken});
}

class HttpNotificationDeviceRepository implements NotificationDeviceRepository {
  const HttpNotificationDeviceRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<String> register({
    required String token,
    required String platform,
    String? accessToken,
  }) async {
    final json = await _apiClient.postJson(
      '/api/v1/notifications/devices',
      body: {'token': token, 'platform': platform},
      accessToken: accessToken,
    );
    return json['id'] as String;
  }

  @override
  Future<void> delete({required String deviceId, String? accessToken}) {
    return _apiClient.deleteNoContent(
      '/api/v1/notifications/devices/$deviceId',
      accessToken: accessToken,
    );
  }
}
