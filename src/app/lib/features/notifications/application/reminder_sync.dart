import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:studyflow_app/core/settings/app_settings_controller.dart';
import 'package:studyflow_app/core/widgets/date_time_pickers.dart';
import 'package:studyflow_app/features/agenda/data/agenda_repository.dart';
import 'package:studyflow_app/features/agenda/domain/agenda_models.dart';
import 'package:studyflow_app/features/auth/application/session_controller.dart';
import 'package:studyflow_app/features/notifications/application/local_notification_scheduler.dart';
import 'package:studyflow_app/features/notifications/application/reminder_planner.dart';
import 'package:studyflow_app/features/notifications/domain/notification_models.dart';
import 'package:studyflow_app/features/schedule/data/course_repository.dart';
import 'package:studyflow_app/features/schedule/domain/course_models.dart';

/// Tient à jour les rappels programmés sur le téléphone.
///
/// Quand l'appareil reçoit les notifications push (Android avec Firebase), le
/// serveur envoie lui-même les rappels : on ne programme rien localement pour
/// éviter les doublons. Sinon (iPhone sans clé APNs, par exemple), les rappels
/// sont programmés ici, à l'ouverture de l'app et après chaque modification.
class ReminderSync {
  ReminderSync({
    required SessionController sessionController,
    required AppSettingsController settingsController,
    required CourseRepository courseRepository,
    required AgendaRepository agendaRepository,
    required LocalNotificationScheduler scheduler,
    required bool Function() deliveredByPush,
    List<ScheduledReminder> Function()? localReminders,
    this.autoSync = true,
  }) : _localReminders = localReminders ?? _none,
       _sessionController = sessionController,
       _settingsController = settingsController,
       _courseRepository = courseRepository,
       _agendaRepository = agendaRepository,
       _scheduler = scheduler,
       _deliveredByPush = deliveredByPush;

  static const _planner = ReminderPlanner();
  static const _horizonDays = 21;

  final SessionController _sessionController;
  final AppSettingsController _settingsController;
  final CourseRepository _courseRepository;
  final AgendaRepository _agendaRepository;
  final LocalNotificationScheduler _scheduler;
  final bool Function() _deliveredByPush;

  /// Rappels propres au téléphone (note du soir), programmés même quand les
  /// autres arrivent par push.
  final List<ScheduledReminder> Function() _localReminders;

  static List<ScheduledReminder> _none() => const [];

  /// Désactivé en mode démo : rien à programmer pour de faux comptes.
  final bool autoSync;

  bool _running = false;
  bool _pending = false;

  /// Les rappels arrivent par notification push plutôt que programmés ici.
  bool get deliveredByPush => _deliveredByPush();

  /// Demande une mise à jour ; plusieurs demandes rapprochées n'en font qu'une.
  void requestSync() {
    if (!autoSync) return;
    if (_running) {
      _pending = true;
      return;
    }
    unawaited(_run());
  }

  Future<void> _run() async {
    _running = true;
    try {
      do {
        _pending = false;
        await refresh();
      } while (_pending);
    } on Object catch (error) {
      // Hors connexion : les rappels déjà programmés restent en place.
      debugPrint('Rappels non mis à jour : $error');
    } finally {
      _running = false;
    }
  }

  /// Calcule les rappels à venir et les programme si besoin. Renvoie la liste
  /// prévue (affichée dans le profil), qu'elle parte du téléphone ou du serveur.
  Future<List<ScheduledReminder>> refresh() async {
    if (_sessionController.session == null) {
      await _scheduler.replaceAll(const []);
      return const [];
    }

    final reminders = await plan();
    final now = DateTime.now();
    final quietHours = _settingsController.quietHours;
    final local = _localReminders()
        .where((reminder) => reminder.scheduledAt.isAfter(now))
        .where((reminder) => !quietHours.isQuietAt(reminder.scheduledAt))
        .toList();
    await _scheduler.replaceAll([if (!deliveredByPush) ...reminders, ...local]);
    return [...reminders, ...local]
      ..sort((left, right) => left.scheduledAt.compareTo(right.scheduledAt));
  }

  Future<List<ScheduledReminder>> plan() async {
    final accessToken = await _sessionController.accessTokenForApi();
    final hasClass = _sessionController.session?.user.schoolClassId != null;
    final today = DateTime.now();
    final from = DateTime(today.year, today.month, today.day);

    final courses = hasClass
        ? await _courseRepository.listCourses(
            from: from,
            to: StudyFlowDates.addDays(from, _horizonDays),
            accessToken: accessToken,
          )
        : const <CourseItem>[];

    // Les tâches et événements sont rangés par espace : on lit les deux.
    final professional = _settingsController.hasCompany
        ? 'company'
        : 'apprenticeship';
    final school = await _agendaRepository.getAgenda(
      taskCategory: 'school',
      accessToken: accessToken,
    );
    final work = await _agendaRepository.getAgenda(
      taskCategory: professional,
      accessToken: accessToken,
    );

    return _planner.plan(
      courses: courses,
      homework: school.homework,
      tasks: <AgendaTaskItem>[...school.tasks, ...work.tasks],
      events: <PersonalEventItem>[...school.events, ...work.events],
      settings: _settingsController.currentSettings,
    );
  }
}
