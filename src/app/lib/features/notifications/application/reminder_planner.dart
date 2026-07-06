import 'package:studyflow_app/core/settings/app_settings_controller.dart';
import 'package:studyflow_app/features/agenda/domain/agenda_models.dart';
import 'package:studyflow_app/features/notifications/domain/notification_models.dart';
import 'package:studyflow_app/features/schedule/domain/course_models.dart';

/// Computes the reminders that should be scheduled for the current student.
///
/// This class contains no Flutter UI and no native notification dependency on
/// purpose: it is easy to test, and it mirrors the backend rule that homework
/// reminders happen one day before the deadline.
class ReminderPlanner {
  const ReminderPlanner();

  List<ScheduledReminder> plan({
    required Iterable<CourseItem> courses,
    required Iterable<HomeworkItem> homework,
    required AppSettings settings,
    DateTime? now,
  }) {
    final referenceTime = now ?? DateTime.now();
    final reminders = <ScheduledReminder>[
      if (settings.courseNotificationsEnabled)
        ...courses
            .where((course) => !course.isCancelled)
            .map((course) => _courseReminder(course, settings))
            .whereType<ScheduledReminder>(),
      if (settings.homeworkNotificationsEnabled)
        ...homework
            .where((item) => !item.isDone && item.notificationsEnabled)
            .map(_homeworkReminder),
    ];

    return reminders
        .where((reminder) => reminder.scheduledAt.isAfter(referenceTime))
        .toList()
      ..sort((left, right) => left.scheduledAt.compareTo(right.scheduledAt));
  }

  ScheduledReminder? _courseReminder(CourseItem course, AppSettings settings) {
    final startsAt = _mergeDayAndTime(course.day, course.startsAt);
    if (startsAt == null) return null;

    final scheduledAt = startsAt.subtract(
      Duration(minutes: settings.courseReminderMinutes),
    );

    return ScheduledReminder(
      id: 'course-${course.id}-${settings.courseReminderMinutes}',
      type: ReminderType.course,
      title: course.subjectName,
      body: 'Cours en salle ${course.room} à ${course.startsAt}.',
      scheduledAt: scheduledAt,
      sourceId: course.id,
    );
  }

  ScheduledReminder _homeworkReminder(HomeworkItem homework) {
    final scheduledAt = homework.deadline.subtract(const Duration(days: 1));

    return ScheduledReminder(
      id: 'homework-${homework.id}',
      type: ReminderType.homework,
      title: homework.title,
      body: 'À rendre le ${_formatDate(homework.deadline)}.',
      scheduledAt: scheduledAt,
      sourceId: homework.id,
    );
  }

  DateTime? _mergeDayAndTime(DateTime day, String time) {
    final parts = time.split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;

    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}
