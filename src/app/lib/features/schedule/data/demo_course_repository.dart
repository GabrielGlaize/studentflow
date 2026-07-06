import 'package:studyflow_app/core/demo/demo_session_state.dart';
import 'package:studyflow_app/features/schedule/data/course_repository.dart';
import 'package:studyflow_app/features/schedule/domain/course_models.dart';

class DemoCourseRepository implements CourseRepository {
  const DemoCourseRepository();

  static final List<CourseItem> _courses = [];
  static DateTime? _seedWeekStart;

  @override
  Future<List<CourseItem>> listCourses({
    required DateTime from,
    required DateTime to,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (DemoSessionState.hasNoClass(accessToken)) return const [];

    final start = DateTime(from.year, from.month, from.day);
    _seedIfNeeded(start);

    return _courses
        .where(
          (course) => !course.day.isBefore(from) && !course.day.isAfter(to),
        )
        .toList(growable: false);
  }

  @override
  Future<CourseItem> createCourse({
    required CourseFormData data,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (DemoSessionState.hasNoClass(accessToken)) {
      throw StateError('Rejoins une classe pour créer un cours partagé.');
    }
    _throwIfConflict(data);

    final course = _fromFormData(
      id: 'course-${_courses.length + 1}',
      data: data,
    );
    _courses.add(course);
    return course;
  }

  @override
  Future<CourseItem> updateCourse({
    required String courseId,
    required CourseFormData data,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    _throwIfConflict(data, excludedCourseId: courseId);

    final index = _courses.indexWhere((course) => course.id == courseId);
    final updatedCourse = _fromFormData(
      id: courseId,
      data: data,
      version: (data.version ?? 1) + 1,
    );

    if (index == -1) {
      _courses.add(updatedCourse);
    } else {
      _courses[index] = updatedCourse;
    }

    return updatedCourse;
  }

  @override
  Future<void> deleteCourse({
    required String courseId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));
    _courses.removeWhere((course) => course.id == courseId);
  }

  @override
  Future<List<CourseRevisionItem>> listCourseRevisions({
    required String courseId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    return [
      CourseRevisionItem(
        id: 'revision-$courseId-2',
        action: 'Updated',
        authorName: 'Gabriel Dubois',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        version: 2,
      ),
      CourseRevisionItem(
        id: 'revision-$courseId-1',
        action: 'Created',
        authorName: 'Sarah Bernard',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        version: 1,
      ),
    ];
  }

  @override
  Future<CourseItem> restoreLatestCourse({
    required String courseId,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final course = _courses.firstWhere((course) => course.id == courseId);
    final restored = CourseItem(
      id: course.id,
      subjectId: course.subjectId,
      subjectName: course.subjectName,
      teacherId: course.teacherId,
      teacherName: course.teacherName,
      day: course.day,
      startsAt: course.startsAt,
      endsAt: course.endsAt,
      room: course.room,
      isCancelled: false,
      version: course.version + 1,
    );
    final index = _courses.indexWhere((item) => item.id == courseId);
    _courses[index] = restored;
    return restored;
  }

  void _seedIfNeeded(DateTime start) {
    if (_seedWeekStart == start && _courses.isNotEmpty) return;

    _seedWeekStart = start;
    _courses
      ..clear()
      ..addAll([
        CourseItem(
          id: 'course-1',
          subjectId: 'subject-flutter',
          subjectName: 'Flutter',
          teacherId: 'teacher-1',
          teacherName: 'Mme Dupont',
          day: start,
          startsAt: '10:15',
          endsAt: '12:15',
          room: 'B204',
          isCancelled: false,
          version: 1,
        ),
        CourseItem(
          id: 'course-2',
          subjectId: 'subject-api',
          subjectName: 'API ASP.NET Core',
          teacherId: 'teacher-2',
          teacherName: 'M. Martin',
          day: start.add(const Duration(days: 1)),
          startsAt: '08:30',
          endsAt: '10:30',
          room: 'A112',
          isCancelled: false,
          version: 1,
        ),
        CourseItem(
          id: 'course-3',
          subjectId: 'subject-db',
          subjectName: 'Base de données',
          day: start.add(const Duration(days: 2)),
          startsAt: '14:00',
          endsAt: '16:00',
          room: 'C301',
          isCancelled: true,
          version: 2,
        ),
      ]);
  }

  CourseItem _fromFormData({
    required String id,
    required CourseFormData data,
    int? version,
  }) {
    return CourseItem(
      id: id,
      subjectId: 'subject-${data.subjectName.toLowerCase()}',
      subjectName: data.subjectName.trim(),
      teacherId: data.teacherName == null
          ? null
          : 'teacher-${data.teacherName}',
      teacherName: data.teacherName?.trim(),
      day: data.day,
      startsAt: data.startsAt,
      endsAt: data.endsAt,
      room: data.room.trim(),
      isCancelled: data.isCancelled,
      version: version ?? data.version ?? 1,
    );
  }

  void _throwIfConflict(CourseFormData data, {String? excludedCourseId}) {
    if (data.isCancelled) return;

    final start = _minutes(data.startsAt);
    final end = _minutes(data.endsAt);
    final hasConflict = _courses.any((course) {
      if (course.id == excludedCourseId || course.isCancelled) return false;
      final sameDay =
          course.day.year == data.day.year &&
          course.day.month == data.day.month &&
          course.day.day == data.day.day;
      if (!sameDay) return false;

      return start < _minutes(course.endsAt) && end > _minutes(course.startsAt);
    });

    if (hasConflict) {
      throw StateError('Ce cours chevauche déjà un autre cours.');
    }
  }

  int _minutes(String value) {
    final parts = value.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}
