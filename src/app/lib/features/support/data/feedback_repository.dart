import 'package:studyflow_app/core/network/api_client.dart';

enum FeedbackKind { idea, bug }

/// Idées et bugs remontés au responsable de l'app.
abstract interface class FeedbackRepository {
  Future<void> send({
    required FeedbackKind kind,
    required String message,
    required String appVersion,
    required String platform,
    String? accessToken,
  });
}

class HttpFeedbackRepository implements FeedbackRepository {
  const HttpFeedbackRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<void> send({
    required FeedbackKind kind,
    required String message,
    required String appVersion,
    required String platform,
    String? accessToken,
  }) {
    return _apiClient.postNoContent(
      '/api/v1/feedback',
      accessToken: accessToken,
      body: {
        'kind': kind.name,
        'message': message.trim(),
        'appVersion': appVersion,
        'platform': platform,
      },
    );
  }
}

/// Mode démo : rien ne part, mais le parcours reste testable.
class DemoFeedbackRepository implements FeedbackRepository {
  const DemoFeedbackRepository();

  static final List<String> sent = [];

  @override
  Future<void> send({
    required FeedbackKind kind,
    required String message,
    required String appVersion,
    required String platform,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    sent.add('${kind.name}: ${message.trim()}');
  }
}
