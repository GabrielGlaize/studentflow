import 'package:studyflow_app/core/network/api_client.dart';
import 'package:studyflow_app/features/announcements/data/class_announcement_repository.dart';
import 'package:studyflow_app/features/announcements/domain/class_announcement_models.dart';

class HttpClassAnnouncementRepository implements ClassAnnouncementRepository {
  const HttpClassAnnouncementRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<ClassAnnouncement>> listAnnouncements({
    bool pinnedOnly = false,
    String? accessToken,
  }) async {
    final path = pinnedOnly
        ? '/api/v1/class-announcements?pinnedOnly=true'
        : '/api/v1/class-announcements';
    final json = await _apiClient.getJsonList(path, accessToken: accessToken);
    return json.map(ClassAnnouncement.fromJson).toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<ClassAnnouncement> createAnnouncement({
    required String content,
    required bool isPinned,
    String? accessToken,
  }) async {
    final json = await _apiClient.postJson(
      '/api/v1/class-announcements',
      body: {'content': content.trim(), 'isPinned': isPinned},
      accessToken: accessToken,
    );
    return ClassAnnouncement.fromJson(json);
  }

  @override
  Future<void> deleteAnnouncement({
    required String announcementId,
    String? accessToken,
  }) {
    return _apiClient.deleteNoContent(
      '/api/v1/class-announcements/$announcementId',
      accessToken: accessToken,
    );
  }

  @override
  Future<ClassAnnouncement> updateAnnouncement({
    required ClassAnnouncement announcement,
    required bool isPinned,
    String? accessToken,
  }) async {
    final json = await _apiClient.putJson(
      '/api/v1/class-announcements/${announcement.id}',
      body: {'content': announcement.content.trim(), 'isPinned': isPinned},
      accessToken: accessToken,
    );
    return ClassAnnouncement.fromJson(json);
  }
}
