import 'package:studyflow_app/core/demo/demo_session_state.dart';
import 'package:studyflow_app/features/announcements/data/class_announcement_repository.dart';
import 'package:studyflow_app/features/announcements/domain/class_announcement_models.dart';

class DemoClassAnnouncementRepository implements ClassAnnouncementRepository {
  const DemoClassAnnouncementRepository();

  static final List<ClassAnnouncement> _announcements = [
    ClassAnnouncement(
      id: 'announcement-1',
      content: 'La salle du partiel a changé : rendez-vous en B204.',
      isPinned: true,
      authorName: 'Délégué',
      createdAt: DateTime(2026, 6, 24, 9),
      updatedAt: DateTime(2026, 6, 24, 9),
    ),
    ClassAnnouncement(
      id: 'announcement-2',
      content: 'Pensez à apporter vos ordinateurs pour le TP API.',
      isPinned: false,
      authorName: 'Délégué',
      createdAt: DateTime(2026, 6, 23, 16, 30),
      updatedAt: DateTime(2026, 6, 23, 16, 30),
    ),
  ];

  @override
  Future<List<ClassAnnouncement>> listAnnouncements({
    bool pinnedOnly = false,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (DemoSessionState.hasNoClass(accessToken)) return const [];
    return _announcements
        .where((announcement) => !pinnedOnly || announcement.isPinned)
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<ClassAnnouncement> createAnnouncement({
    required String content,
    required bool isPinned,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (DemoSessionState.hasNoClass(accessToken)) {
      throw StateError('Rejoins une classe pour publier une annonce.');
    }

    final now = DateTime.now();
    final announcement = ClassAnnouncement(
      id: 'announcement-${_announcements.length + 1}',
      content: content.trim(),
      isPinned: isPinned,
      authorName: 'Gabriel Demo',
      createdAt: now,
      updatedAt: now,
    );
    _announcements.insert(0, announcement);
    return announcement;
  }

  @override
  Future<void> deleteAnnouncement({
    required String announcementId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (DemoSessionState.hasNoClass(accessToken)) {
      throw StateError('Rejoins une classe pour supprimer une annonce.');
    }

    _announcements.removeWhere(
      (announcement) => announcement.id == announcementId,
    );
  }
}
