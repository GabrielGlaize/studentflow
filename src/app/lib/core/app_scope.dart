import 'package:flutter/widgets.dart';
import 'package:studyflow_app/features/auth/application/session_controller.dart';
import 'package:studyflow_app/core/settings/app_settings_controller.dart';
import 'package:studyflow_app/features/agenda/data/agenda_repository.dart';
import 'package:studyflow_app/features/announcements/data/class_announcement_repository.dart';
import 'package:studyflow_app/features/apprenticeships/data/apprenticeship_repository.dart';
import 'package:studyflow_app/features/classes/data/class_management_repository.dart';
import 'package:studyflow_app/features/classes/data/class_resource_repository.dart';
import 'package:studyflow_app/features/dashboard/data/dashboard_repository.dart';
import 'package:studyflow_app/features/company/application/company_contacts_controller.dart';
import 'package:studyflow_app/features/company/application/company_documents_controller.dart';
import 'package:studyflow_app/features/notifications/application/local_notification_scheduler.dart';
import 'package:studyflow_app/features/profile/data/app_preferences_repository.dart';
import 'package:studyflow_app/features/profile/data/notification_preferences_repository.dart';
import 'package:studyflow_app/features/schedule/data/course_repository.dart';

/// Gives the widget tree access to app-wide services.
///
/// We keep this intentionally simple for the MVP: no external state-management
/// package yet. Later, this can be replaced by Provider, Riverpod or Bloc
/// without changing the domain models.
class AppScope extends InheritedWidget {
  const AppScope({
    required this.sessionController,
    required this.settingsController,
    required this.agendaRepository,
    required this.classAnnouncementRepository,
    required this.apprenticeshipRepository,
    required this.classManagementRepository,
    required this.classResourceRepository,
    required this.companyContactsController,
    required this.companyDocumentsController,
    required this.dashboardRepository,
    required this.appPreferencesRepository,
    required this.notificationPreferencesRepository,
    required this.notificationScheduler,
    required this.courseRepository,
    required super.child,
    super.key,
  });

  final SessionController sessionController;
  final AppSettingsController settingsController;
  final AgendaRepository agendaRepository;
  final ClassAnnouncementRepository classAnnouncementRepository;
  final ApprenticeshipRepository apprenticeshipRepository;
  final ClassManagementRepository classManagementRepository;
  final ClassResourceRepository classResourceRepository;
  final CompanyContactsController companyContactsController;
  final CompanyDocumentsController companyDocumentsController;
  final DashboardRepository dashboardRepository;
  final AppPreferencesRepository appPreferencesRepository;
  final NotificationPreferencesRepository notificationPreferencesRepository;
  final LocalNotificationScheduler notificationScheduler;
  final CourseRepository courseRepository;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) {
    return sessionController != oldWidget.sessionController ||
        settingsController != oldWidget.settingsController ||
        agendaRepository != oldWidget.agendaRepository ||
        classAnnouncementRepository != oldWidget.classAnnouncementRepository ||
        apprenticeshipRepository != oldWidget.apprenticeshipRepository ||
        classManagementRepository != oldWidget.classManagementRepository ||
        classResourceRepository != oldWidget.classResourceRepository ||
        companyContactsController != oldWidget.companyContactsController ||
        companyDocumentsController != oldWidget.companyDocumentsController ||
        dashboardRepository != oldWidget.dashboardRepository ||
        appPreferencesRepository != oldWidget.appPreferencesRepository ||
        notificationPreferencesRepository !=
            oldWidget.notificationPreferencesRepository ||
        notificationScheduler != oldWidget.notificationScheduler ||
        courseRepository != oldWidget.courseRepository;
  }
}
