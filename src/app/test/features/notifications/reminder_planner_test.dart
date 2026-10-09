import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_app/core/settings/app_settings_controller.dart';
import 'package:studyflow_app/core/settings/quiet_hours.dart';
import 'package:studyflow_app/features/agenda/domain/agenda_models.dart';
import 'package:studyflow_app/features/notifications/application/local_notification_scheduler.dart';
import 'package:studyflow_app/features/notifications/application/reminder_planner.dart';
import 'package:studyflow_app/features/notifications/domain/notification_models.dart';
import 'package:studyflow_app/features/schedule/domain/course_models.dart';

void main() {
  const planner = ReminderPlanner();

  test('planifie un rappel de cours avec le délai configuré', () {
    final reminders = planner.plan(
      courses: [
        CourseItem(
          id: 'course-1',
          subjectId: 'subject-flutter',
          subjectName: 'Flutter',
          day: DateTime(2026, 6, 25),
          startsAt: '10:15',
          endsAt: '12:15',
          room: 'B204',
          isCancelled: false,
          version: 1,
        ),
      ],
      homework: const [],
      settings: _settings(courseReminderMinutes: 15),
      now: DateTime(2026, 6, 25, 8),
    );

    expect(reminders, hasLength(1));
    expect(reminders.single.type, ReminderType.course);
    expect(reminders.single.scheduledAt, DateTime(2026, 6, 25, 10));
    expect(reminders.single.body, contains('B204'));
  });

  test('ignore les cours annulés et les rappels déjà passés', () {
    final reminders = planner.plan(
      courses: [
        CourseItem(
          id: 'cancelled',
          subjectId: 'subject-db',
          subjectName: 'Base de données',
          day: DateTime(2026, 6, 25),
          startsAt: '14:00',
          endsAt: '16:00',
          room: 'C301',
          isCancelled: true,
          version: 1,
        ),
        CourseItem(
          id: 'past',
          subjectId: 'subject-api',
          subjectName: 'API',
          day: DateTime(2026, 6, 25),
          startsAt: '09:00',
          endsAt: '10:00',
          room: 'A112',
          isCancelled: false,
          version: 1,
        ),
      ],
      homework: const [],
      settings: _settings(courseReminderMinutes: 5),
      now: DateTime(2026, 6, 25, 10),
    );

    expect(reminders, isEmpty);
  });

  test('planifie les devoirs la veille de la deadline', () {
    final reminders = planner.plan(
      courses: const [],
      homework: [
        HomeworkItem(
          id: 'homework-1',
          title: 'Dossier anglais',
          deadline: DateTime(2026, 6, 27, 18),
          isDone: false,
          notificationsEnabled: true,
        ),
      ],
      settings: _settings(),
      now: DateTime(2026, 6, 25, 8),
    );

    expect(reminders, hasLength(1));
    expect(reminders.single.type, ReminderType.homework);
    expect(reminders.single.scheduledAt, DateTime(2026, 6, 26, 18));
  });

  test('chaque devoir, tâche ou événement suit son propre délai', () {
    final reminders = planner.plan(
      courses: const [],
      homework: [
        HomeworkItem(
          id: 'homework-2',
          title: 'Exposé',
          deadline: DateTime(2026, 6, 27, 18),
          isDone: false,
          notificationsEnabled: true,
          reminderMinutesBefore: 180,
        ),
      ],
      tasks: [
        AgendaTaskItem(
          id: 'task-1',
          title: 'Relire le rapport',
          category: 'school',
          isDone: false,
          notificationsEnabled: true,
          deadline: DateTime(2026, 6, 28, 12),
          reminderMinutesBefore: 2880,
        ),
        const AgendaTaskItem(
          id: 'task-without-deadline',
          title: 'Sans échéance',
          category: 'school',
          isDone: false,
          notificationsEnabled: true,
        ),
      ],
      events: [
        PersonalEventItem(
          id: 'event-1',
          title: 'Entretien',
          day: DateTime(2026, 6, 26),
          startsAt: '14:00',
          endsAt: '15:00',
          category: 'apprenticeship',
          notificationsEnabled: true,
          reminderMinutesBefore: 30,
        ),
      ],
      settings: _settings(),
      now: DateTime(2026, 6, 25, 8),
    );

    expect(reminders.map((x) => (x.type, x.scheduledAt)), [
      (ReminderType.task, DateTime(2026, 6, 26, 12)),
      (ReminderType.event, DateTime(2026, 6, 26, 13, 30)),
      (ReminderType.homework, DateTime(2026, 6, 27, 15)),
    ]);
  });

  test('le scheduler mémoire remplace les rappels précédents', () async {
    final scheduler = MemoryLocalNotificationScheduler();
    await scheduler.replaceAll([
      ScheduledReminder(
        id: 'later',
        type: ReminderType.course,
        title: 'Plus tard',
        body: 'Salle B',
        scheduledAt: DateTime(2026, 6, 25, 12),
        sourceId: 'course-later',
      ),
      ScheduledReminder(
        id: 'first',
        type: ReminderType.homework,
        title: 'Avant',
        body: 'À rendre',
        scheduledAt: DateTime(2026, 6, 25, 9),
        sourceId: 'homework-first',
      ),
    ]);

    expect(scheduler.scheduledReminders.map((item) => item.id), [
      'first',
      'later',
    ]);

    await scheduler.replaceAll(const []);
    expect(scheduler.scheduledReminders, isEmpty);
  });
  test('ne pas déranger : rien pendant la plage calme ni la pause', () {
    // Rappel la veille à 18 h (en dehors) et rendu à 23 h la veille (dedans).
    final homework = [
      HomeworkItem(
        id: 'evening',
        title: 'Dossier anglais',
        deadline: DateTime(2026, 6, 27, 18),
        isDone: false,
        notificationsEnabled: true,
      ),
      HomeworkItem(
        id: 'night',
        title: 'QCM en ligne',
        deadline: DateTime(2026, 6, 27, 23),
        isDone: false,
        notificationsEnabled: true,
      ),
    ];
    final now = DateTime(2026, 6, 25, 8);

    final quiet = planner.plan(
      courses: const [],
      homework: homework,
      settings: _settings(quietHours: const QuietHours(enabled: true)),
      now: now,
    );
    expect(quiet.map((reminder) => reminder.sourceId), ['evening']);

    final paused = planner.plan(
      courses: const [],
      homework: homework,
      settings: _settings(
        quietHours: QuietHours(mutedUntil: DateTime(2026, 6, 28)),
      ),
      now: now,
    );
    expect(paused, isEmpty);
  });
}

AppSettings _settings({
  bool courseNotificationsEnabled = true,
  bool homeworkNotificationsEnabled = true,
  int courseReminderMinutes = 5,
  QuietHours quietHours = const QuietHours(),
}) {
  return AppSettings(
    themeMode: ThemeMode.system,
    hasCompany: false,
    courseNotificationsEnabled: courseNotificationsEnabled,
    homeworkNotificationsEnabled: homeworkNotificationsEnabled,
    courseReminderMinutes: courseReminderMinutes,
    quietHours: quietHours,
  );
}
