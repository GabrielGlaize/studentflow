import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_app/features/profile/domain/notification_preferences.dart';

void main() {
  test('NotificationPreferences lit et écrit le JSON API', () {
    final preferences = NotificationPreferences.fromJson({
      'coursesEnabled': true,
      'homeworkEnabled': false,
      'apprenticeshipsEnabled': true,
      'courseReminderMinutes': 10,
    });

    expect(preferences.coursesEnabled, isTrue);
    expect(preferences.homeworkEnabled, isFalse);
    expect(preferences.apprenticeshipsEnabled, isTrue);
    expect(preferences.courseReminderMinutes, 10);
    expect(preferences.toJson(), {
      'coursesEnabled': true,
      'homeworkEnabled': false,
      'apprenticeshipsEnabled': true,
      'courseReminderMinutes': 10,
    });
  });
}
