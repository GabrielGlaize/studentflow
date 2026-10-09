import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_app/core/widgets/reminder_picker.dart';

void main() {
  test('les délais de rappel se lisent naturellement', () {
    expect(ReminderFormat.label(0, atMoment: 'Au début'), 'Au début');
    expect(ReminderFormat.label(15), '15 min avant');
    expect(ReminderFormat.label(90), '1 h 30 avant');
    expect(ReminderFormat.label(1440), 'La veille');
    expect(ReminderFormat.label(2880), '2 jours avant');
    expect(ReminderFormat.label(10080), '1 semaine avant');
    expect(ReminderFormat.label(1500), '1 jour et 1 h avant');
  });

  test('le moment exact du rappel est calculé depuis l’échéance', () {
    final deadline = DateTime(2026, 10, 14, 18);
    expect(
      ReminderFormat.detailed(1440, deadline),
      'La veille · mar. 13/10 à 18:00',
    );
  });
}
