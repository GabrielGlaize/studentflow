import 'package:studyflow_app/features/schedule/domain/course_models.dart';

abstract interface class CourseRepository {
  Future<List<CourseItem>> listCourses({
    required DateTime from,
    required DateTime to,
    String? accessToken,
  });

  Future<CourseItem> createCourse({
    required CourseFormData data,
    String? accessToken,
  });

  Future<CourseItem> updateCourse({
    required String courseId,
    required CourseFormData data,
    String? accessToken,
  });

  Future<void> deleteCourse({required String courseId, String? accessToken});

  Future<List<CourseRevisionItem>> listCourseRevisions({
    required String courseId,
    String? accessToken,
  });

  Future<CourseItem> restoreLatestCourse({
    required String courseId,
    String? accessToken,
  });
}
