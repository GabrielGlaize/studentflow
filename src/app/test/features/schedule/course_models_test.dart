import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_app/features/schedule/domain/course_models.dart';

void main() {
  test('CourseItem.fromJson lit la réponse du backend', () {
    final course = CourseItem.fromJson({
      'id': 'course-1',
      'subjectId': 'subject-1',
      'subjectName': 'Flutter',
      'teacherId': 'teacher-1',
      'teacherName': 'Mme Dupont',
      'day': '2026-06-24',
      'startsAt': '10:15:00',
      'endsAt': '12:15:00',
      'room': 'B204',
      'isCancelled': false,
      'version': 3,
    });

    expect(course.subjectName, 'Flutter');
    expect(course.startsAt, '10:15');
    expect(course.endsAt, '12:15');
    expect(course.version, 3);
  });
}
