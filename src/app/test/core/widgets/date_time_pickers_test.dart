import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_app/core/widgets/date_time_pickers.dart';

void main() {
  test('ajouter des semaines garde le même jour au changement d’heure', () {
    // Passage à l'heure d'hiver le dimanche 25 octobre 2026.
    final thursday = DateTime(2026, 10, 22);

    final nextWeek = StudyFlowDates.addDays(thursday, 7);

    expect(nextWeek, DateTime(2026, 10, 29));
    expect(nextWeek.weekday, DateTime.thursday);
    expect(StudyFlowDates.addDays(thursday, 7 * 6).weekday, DateTime.thursday);
  });

  test('le lundi de la semaine', () {
    expect(
      StudyFlowDates.mondayOf(DateTime(2026, 11, 1)),
      DateTime(2026, 10, 26),
    );
    expect(
      StudyFlowDates.mondayOf(DateTime(2026, 10, 26)),
      DateTime(2026, 10, 26),
    );
  });

  test('les libellés sont en français', () {
    expect(StudyFlowFormat.longDay(DateTime(2026, 10, 8)), 'Jeudi 8 octobre');
    expect(StudyFlowFormat.shortDay(DateTime(2026, 10, 12)), 'lun. 12/10');
    expect(StudyFlowFormat.duration(90), '1 h 30');
    expect(StudyFlowFormat.duration(45), '45 min');
    expect(StudyFlowFormat.time(const TimeOfDay(hour: 8, minute: 5)), '08:05');
  });
}
