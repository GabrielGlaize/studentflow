import 'package:studyflow_app/features/announcements/domain/class_announcement_models.dart';

abstract interface class ClassAnnouncementRepository {
  Future<List<ClassAnnouncement>> listAnnouncements({
    bool pinnedOnly = false,
    String? accessToken,
  });

  Future<ClassAnnouncement> createAnnouncement({
    required String content,
    required bool isPinned,
    String? accessToken,
  });

  Future<ClassAnnouncement> updateAnnouncement({
    required ClassAnnouncement announcement,
    required bool isPinned,
    String? accessToken,
  });

  Future<void> deleteAnnouncement({
    required String announcementId,
    String? accessToken,
  });
}
