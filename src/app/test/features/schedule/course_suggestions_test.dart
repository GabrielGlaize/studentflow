import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_app/features/schedule/domain/course_models.dart';
import 'package:studyflow_app/features/schedule/presentation/course_form_page.dart';

CourseItem _course(
  String start,
  String end, {
  String room = 'B204',
  String subjectId = 'maths',
}) {
  return CourseItem(
    id: '$start-$room',
    subjectId: subjectId,
    subjectName: subjectId,
    day: DateTime(2026, 10, 12),
    startsAt: start,
    endsAt: end,
    room: room,
    isCancelled: false,
    version: 1,
  );
}

void main() {
  test('un jour sans cours propose 8 h – 9 h 30', () {
    final slot = nextCourseSlot(const []);
    expect(slot.$1, const TimeOfDay(hour: 8, minute: 0));
    expect(slot.$2, const TimeOfDay(hour: 9, minute: 30));
  });

  test('le cours suivant démarre 15 min après le dernier, même durée', () {
    final slot = nextCourseSlot([
      _course('08:00', '09:30'),
      _course('09:45', '11:15'),
    ]);
    expect(slot.$1, const TimeOfDay(hour: 11, minute: 30));
    expect(slot.$2, const TimeOfDay(hour: 13, minute: 0));
  });

  test('après une matinée finie à 13 h, on propose 14 h', () {
    final slot = nextCourseSlot([
      _course('08:00', '09:30'),
      _course('09:45', '11:15'),
      _course('11:30', '13:00'),
    ]);
    expect(slot.$1, const TimeOfDay(hour: 14, minute: 0));
    expect(slot.$2, const TimeOfDay(hour: 15, minute: 30));
  });

  test('les salles du mois sont triées, celles de la matière en tête', () {
    final rooms = roomSuggestions([
      _course('08:00', '09:00', room: 'A112', subjectId: 'anglais'),
      _course('09:00', '10:00', room: 'A112', subjectId: 'anglais'),
      _course('10:00', '11:00', room: 'C301', subjectId: 'maths'),
      _course('14:00', '15:00', room: ' ', subjectId: 'maths'),
    ], subjectId: 'maths');

    expect(rooms, ['C301', 'A112']);
  });
}
