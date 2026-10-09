import 'package:studyflow_app/core/settings/app_settings_controller.dart';
import 'package:studyflow_app/core/widgets/reminder_picker.dart';
import 'package:studyflow_app/features/agenda/domain/agenda_models.dart';
import 'package:studyflow_app/features/notifications/domain/notification_models.dart';
import 'package:studyflow_app/features/schedule/domain/course_models.dart';

/// Calcule les rappels à programmer pour l'élève connecté.
///
/// Aucune dépendance à Flutter ni aux notifications natives : c'est testable,
/// et cela suit les mêmes règles que le serveur (délai choisi par l'élève pour
/// chaque devoir, tâche ou événement ; délai global pour les cours).
class ReminderPlanner {
  const ReminderPlanner();

  List<ScheduledReminder> plan({
    required Iterable<CourseItem> courses,
    required Iterable<HomeworkItem> homework,
    required AppSettings settings,
    Iterable<AgendaTaskItem> tasks = const [],
    Iterable<PersonalEventItem> events = const [],
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
      ...tasks
          .where(
            (task) =>
                !task.isDone &&
                task.notificationsEnabled &&
                task.deadline != null,
          )
          .map(_taskReminder),
      ...events
          .where((event) => event.notificationsEnabled)
          .map(_eventReminder),
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
    final minutes = homework.reminderMinutesBefore;

    return ScheduledReminder(
      id: 'homework-${homework.id}-$minutes',
      type: ReminderType.homework,
      title: homework.title,
      body:
          'À rendre le ${_formatDate(homework.deadline)} (${_when(minutes)}).',
      scheduledAt: homework.deadline.subtract(Duration(minutes: minutes)),
      sourceId: homework.id,
    );
  }

  ScheduledReminder _taskReminder(AgendaTaskItem task) {
    final minutes = task.reminderMinutesBefore;

    return ScheduledReminder(
      id: 'task-${task.id}-$minutes',
      type: ReminderType.task,
      title: task.title,
      body: 'Échéance le ${_formatDate(task.deadline!)} (${_when(minutes)}).',
      scheduledAt: task.deadline!.subtract(Duration(minutes: minutes)),
      sourceId: task.id,
    );
  }

  ScheduledReminder _eventReminder(PersonalEventItem event) {
    final minutes = event.reminderMinutesBefore;
    final place = event.location == null ? '' : ' · ${event.location}';

    return ScheduledReminder(
      id: 'event-${event.id}-$minutes',
      type: ReminderType.event,
      title: event.title,
      body: 'Commence à ${event.startsAt}$place.',
      scheduledAt: event.startDateTime.subtract(Duration(minutes: minutes)),
      sourceId: event.id,
    );
  }

  /// « la veille », « 1 h avant »…
  String _when(int minutes) =>
      ReminderFormat.label(minutes, atMoment: 'maintenant').toLowerCase();

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
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month à $hour:$minute';
  }
}
