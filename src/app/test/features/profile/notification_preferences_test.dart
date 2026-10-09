import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_app/core/settings/quiet_hours.dart';
import 'package:studyflow_app/features/profile/domain/notification_preferences.dart';

void main() {
  test('NotificationPreferences lit et écrit le JSON API', () {
    final preferences = NotificationPreferences.fromJson({
      'coursesEnabled': true,
      'homeworkEnabled': false,
      'apprenticeshipsEnabled': true,
      'courseReminderMinutes': 10,
      'quietHoursEnabled': true,
      'quietHoursStart': '22:30:00',
      'quietHoursEnd': '07:00:00',
      'mutedUntil': null,
    });

    expect(preferences.coursesEnabled, isTrue);
    expect(preferences.homeworkEnabled, isFalse);
    expect(preferences.apprenticeshipsEnabled, isTrue);
    expect(preferences.courseReminderMinutes, 10);
    expect(preferences.quietHours.enabled, isTrue);
    expect(preferences.quietHours.startMinutes, 22 * 60 + 30);
    expect(preferences.toJson(), {
      'coursesEnabled': true,
      'homeworkEnabled': false,
      'apprenticeshipsEnabled': true,
      'courseReminderMinutes': 10,
      'quietHoursEnabled': true,
      'quietHoursStart': '22:30:00',
      'quietHoursEnd': '07:00:00',
      // Pas de pause : un instant passé l'arrête côté serveur.
      'mutedUntil': '1970-01-01T00:00:00.000Z',
    });
  });

  test(
    'une ancienne réponse sans plage calme garde les valeurs par défaut',
    () {
      final preferences = NotificationPreferences.fromJson({
        'coursesEnabled': true,
        'homeworkEnabled': true,
        'apprenticeshipsEnabled': true,
        'courseReminderMinutes': 5,
      });

      expect(preferences.quietHours, const QuietHours());
    },
  );

  group('QuietHours', () {
    const nightly = QuietHours(enabled: true);

    test('la plage calme passe minuit', () {
      expect(nightly.isQuietAt(DateTime(2026, 10, 9, 23, 15)), isTrue);
      expect(nightly.isQuietAt(DateTime(2026, 10, 10, 6, 59)), isTrue);
      expect(nightly.isQuietAt(DateTime(2026, 10, 10, 7)), isFalse);
      expect(nightly.isQuietAt(DateTime(2026, 10, 9, 21, 59)), isFalse);
    });

    test('désactivée, elle ne bloque rien', () {
      expect(const QuietHours().isQuietAt(DateTime(2026, 10, 9, 23)), isFalse);
    });

    test('une pause bloque tout jusqu’à son terme', () {
      final paused = QuietHours(mutedUntil: DateTime(2026, 10, 9, 16));
      expect(paused.isQuietAt(DateTime(2026, 10, 9, 15, 30)), isTrue);
      expect(paused.isQuietAt(DateTime(2026, 10, 9, 16, 1)), isFalse);
    });
  });
}
