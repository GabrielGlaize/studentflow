import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_app/features/announcements/domain/class_announcement_models.dart';

void main() {
  test('ClassAnnouncement.fromJson lit la réponse du backend', () {
    final announcement = ClassAnnouncement.fromJson({
      'id': 'announcement-1',
      'content': 'Salle modifiée.',
      'isPinned': true,
      'authorName': 'Délégué',
      'createdAt': '2026-06-24T09:00:00Z',
      'updatedAt': '2026-06-24T09:00:00Z',
    });

    expect(announcement.content, 'Salle modifiée.');
    expect(announcement.isPinned, isTrue);
    expect(announcement.authorName, 'Délégué');
  });
}
