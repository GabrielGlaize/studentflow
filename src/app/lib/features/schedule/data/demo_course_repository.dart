import 'package:studyflow_app/core/demo/demo_session_state.dart';
import 'package:studyflow_app/features/schedule/data/course_repository.dart';
import 'package:studyflow_app/features/schedule/domain/course_models.dart';

class DemoCourseRepository implements CourseRepository {
  const DemoCourseRepository();

  static final List<CourseItem> _courses = [];
  static bool _seeded = false;

  @override
  Future<List<CourseItem>> listCourses({
    required DateTime from,
    required DateTime to,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (DemoSessionState.hasNoClass(accessToken)) return const [];

    _seedIfNeeded();

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
  Future<List<CourseItem>> createCourses({
    required List<CourseFormData> courses,
    String? accessToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (DemoSessionState.hasNoClass(accessToken)) {
      throw StateError('Rejoins une classe pour créer un cours partagé.');
    }
    for (var i = 0; i < courses.length; i++) {
      _throwIfConflict(courses[i]);
      for (final other in courses.skip(i + 1)) {
        if (_overlaps(courses[i], other)) {
          throw StateError(
            'Deux de tes créneaux se chevauchent. Décale l’un des deux.',
          );
        }
      }
    }

    final created = [
      for (final data in courses)
        _fromFormData(
          id: 'course-${DateTime.now().microsecondsSinceEpoch}-${data.startsAt}',
          data: data,
        ),
    ];
    _courses.addAll(created);
    return created;
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

  /// Une semaine type, une seule fois : changer de semaine ou lire le mois
  /// ne doit pas effacer les cours ajoutés pendant la démo.
  void _seedIfNeeded() {
    if (_seeded) return;
    _seeded = true;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    _courses
      ..clear()
      ..addAll([
        CourseItem(
          id: 'course-1',
          subjectId: 'subject-2',
          subjectName: 'Développement',
          teacherId: 'teacher-1',
          teacherName: 'Mme Martin',
          day: start,
          startsAt: '10:15',
          endsAt: '12:15',
          room: 'B204',
          isCancelled: false,
          version: 1,
        ),
        CourseItem(
          id: 'course-2',
          subjectId: 'subject-1',
          subjectName: 'Mathématiques',
          teacherId: 'teacher-2',
          teacherName: 'M. Bernard',
          day: DateTime(start.year, start.month, start.day + 1),
          startsAt: '08:30',
          endsAt: '10:30',
          room: 'A112',
          isCancelled: false,
          version: 1,
        ),
        CourseItem(
          id: 'course-3',
          subjectId: 'subject-3',
          subjectName: 'Réseaux',
          day: DateTime(start.year, start.month, start.day + 2),
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
      subjectId: data.subjectId,
      subjectName: data.subjectName.trim(),
      teacherId: data.teacherId,
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
      throw StateError(
        'Il y a déjà un cours sur ce créneau. Choisis un autre horaire.',
      );
    }
  }

  bool _overlaps(CourseFormData first, CourseFormData second) {
    if (first.isCancelled || second.isCancelled) return false;
    final sameDay =
        first.day.year == second.day.year &&
        first.day.month == second.day.month &&
        first.day.day == second.day.day;
    return sameDay &&
        _minutes(first.startsAt) < _minutes(second.endsAt) &&
        _minutes(first.endsAt) > _minutes(second.startsAt);
  }

  int _minutes(String value) {
    final parts = value.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}
