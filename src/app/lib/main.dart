import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/config/app_environment.dart';
import 'package:studyflow_app/core/config/api_config.dart';
import 'package:studyflow_app/core/config/firebase_config.dart';
import 'package:studyflow_app/core/network/api_client.dart';
import 'package:studyflow_app/core/settings/app_settings_controller.dart';
import 'package:studyflow_app/core/theme/app_theme.dart';
import 'package:studyflow_app/features/agenda/data/agenda_repository.dart';
import 'package:studyflow_app/features/agenda/data/demo_agenda_repository.dart';
import 'package:studyflow_app/features/agenda/data/http_agenda_repository.dart';
import 'package:studyflow_app/features/announcements/data/class_announcement_repository.dart';
import 'package:studyflow_app/features/announcements/data/demo_class_announcement_repository.dart';
import 'package:studyflow_app/features/announcements/data/http_class_announcement_repository.dart';
import 'package:studyflow_app/features/apprenticeships/data/apprenticeship_repository.dart';
import 'package:studyflow_app/features/apprenticeships/data/demo_apprenticeship_repository.dart';
import 'package:studyflow_app/features/apprenticeships/data/http_apprenticeship_repository.dart';
import 'package:studyflow_app/features/auth/application/session_controller.dart';
import 'package:studyflow_app/features/auth/data/auth_repository.dart';
import 'package:studyflow_app/features/auth/data/demo_auth_repository.dart';
import 'package:studyflow_app/features/auth/data/http_auth_repository.dart';
import 'package:studyflow_app/features/auth/data/session_storage.dart';
import 'package:studyflow_app/features/auth/presentation/login_page.dart';
import 'package:studyflow_app/features/classes/data/class_management_repository.dart';
import 'package:studyflow_app/features/classes/data/class_resource_repository.dart';
import 'package:studyflow_app/features/classes/data/demo_class_management_repository.dart';
import 'package:studyflow_app/features/classes/data/demo_class_resource_repository.dart';
import 'package:studyflow_app/features/classes/data/http_class_management_repository.dart';
import 'package:studyflow_app/features/classes/data/http_class_resource_repository.dart';
import 'package:studyflow_app/features/company/application/company_contacts_controller.dart';
import 'package:studyflow_app/features/company/application/company_documents_controller.dart';
import 'package:studyflow_app/features/dashboard/data/dashboard_repository.dart';
import 'package:studyflow_app/features/dashboard/data/demo_dashboard_repository.dart';
import 'package:studyflow_app/features/dashboard/data/http_dashboard_repository.dart';
import 'package:studyflow_app/features/support/data/feedback_repository.dart';
import 'package:studyflow_app/features/notes/data/daily_note_repository.dart';
import 'package:studyflow_app/features/notes/application/daily_notes_controller.dart';
import 'package:studyflow_app/features/exams/data/demo_exam_repository.dart';
import 'package:studyflow_app/features/exams/data/exam_repository.dart';
import 'package:studyflow_app/features/exams/data/http_exam_repository.dart';
import 'package:studyflow_app/features/notifications/application/local_notification_scheduler.dart';
import 'package:studyflow_app/features/notifications/application/push_notification_service.dart';
import 'package:studyflow_app/features/notifications/application/reminder_sync.dart';
import 'package:studyflow_app/features/notifications/data/notification_device_repository.dart';
import 'package:studyflow_app/features/profile/data/app_preferences_repository.dart';
import 'package:studyflow_app/features/profile/data/demo_app_preferences_repository.dart';
import 'package:studyflow_app/features/profile/data/demo_notification_preferences_repository.dart';
import 'package:studyflow_app/features/profile/data/http_app_preferences_repository.dart';
import 'package:studyflow_app/features/profile/data/http_notification_preferences_repository.dart';
import 'package:studyflow_app/features/profile/data/notification_preferences_repository.dart';
import 'package:studyflow_app/features/schedule/data/course_repository.dart';
import 'package:studyflow_app/features/schedule/data/demo_course_repository.dart';
import 'package:studyflow_app/features/schedule/data/http_course_repository.dart';
import 'package:studyflow_app/features/shell/presentation/main_shell.dart';

void main() {
  runStudyFlowApp(const AppEnvironment.dev());
}

void runStudyFlowApp(AppEnvironment environment) {
  runApp(StudyFlowApp(environment: environment));
}

class StudyFlowApp extends StatefulWidget {
  const StudyFlowApp({required this.environment, super.key});

  final AppEnvironment environment;

  @override
  State<StudyFlowApp> createState() => _StudyFlowAppState();
}

class _StudyFlowAppState extends State<StudyFlowApp>
    with WidgetsBindingObserver {
  static const _useDemoAuthOverride = String.fromEnvironment(
    'STUDYFLOW_USE_DEMO_AUTH',
  );
  static const _useDemoDashboardOverride = String.fromEnvironment(
    'STUDYFLOW_USE_DEMO_DASHBOARD',
  );
  static const _useDemoAgendaOverride = String.fromEnvironment(
    'STUDYFLOW_USE_DEMO_AGENDA',
  );
  static const _useDemoApprenticeshipsOverride = String.fromEnvironment(
    'STUDYFLOW_USE_DEMO_APPRENTICESHIPS',
  );
  static const _useDemoAnnouncementsOverride = String.fromEnvironment(
    'STUDYFLOW_USE_DEMO_ANNOUNCEMENTS',
  );
  static const _useDemoCoursesOverride = String.fromEnvironment(
    'STUDYFLOW_USE_DEMO_COURSES',
  );
  static const _useDemoClassManagementOverride = String.fromEnvironment(
    'STUDYFLOW_USE_DEMO_CLASS_MANAGEMENT',
  );
  static const _useDemoClassResourcesOverride = String.fromEnvironment(
    'STUDYFLOW_USE_DEMO_CLASS_RESOURCES',
  );
  static const _useDemoNotificationPreferencesOverride = String.fromEnvironment(
    'STUDYFLOW_USE_DEMO_NOTIFICATION_PREFERENCES',
  );
  static const _useDemoAppPreferencesOverride = String.fromEnvironment(
    'STUDYFLOW_USE_DEMO_APP_PREFERENCES',
  );
  static const _useDemoExamsOverride = String.fromEnvironment(
    'STUDYFLOW_USE_DEMO_EXAMS',
  );

  late final SessionController _sessionController;
  late final AppSettingsController _settingsController;
  late final CompanyContactsController _companyContactsController;
  late final CompanyDocumentsController _companyDocumentsController;
  late final DailyNotesController _dailyNotesController;
  late final LocalNotificationScheduler _notificationScheduler;

  // Un seul client HTTP partagé, créé une fois : avant, chaque reconstruction
  // de l'arbre recréait tous les dépôts et leurs connexions.
  late final ApiClient _apiClient;
  late final AgendaRepository _agendaRepository;
  late final ClassAnnouncementRepository _classAnnouncementRepository;
  late final ApprenticeshipRepository _apprenticeshipRepository;
  late final ClassManagementRepository _classManagementRepository;
  late final ClassResourceRepository _classResourceRepository;
  late final DashboardRepository _dashboardRepository;
  late final AppPreferencesRepository _appPreferencesRepository;
  late final NotificationPreferencesRepository
  _notificationPreferencesRepository;
  late final CourseRepository _courseRepository;
  late final ExamRepository _examRepository;
  late final FeedbackRepository _feedbackRepository;
  late final PushNotificationService _pushNotifications;
  late final ReminderSync _reminderSync;
  String? _syncedUserId;

  @override
  void initState() {
    super.initState();
    _settingsController = AppSettingsController(
      storage: SecureAppSettingsStorage(),
    );
    _companyContactsController = CompanyContactsController(
      storage: SecureCompanyContactsStorage(),
    );
    _companyDocumentsController = CompanyDocumentsController(
      storage: SecureCompanyDocumentsStorage(),
    );
    _notificationScheduler = NativeLocalNotificationScheduler();
    final authRepository = _buildAuthRepository();
    _sessionController = SessionController(
      authRepository: authRepository,
      sessionStorage: _buildSessionStorage(),
    );
    _apiClient = ApiClient(baseUrl: ApiConfig.baseUrlFor(widget.environment))
      ..onAccessTokenRejected = _sessionController.renewRejectedAccessToken;
    final demoNotes = _useDemoRepository(_useDemoAuthOverride);
    _dailyNotesController = DailyNotesController(
      // Mode démo : carnet en mémoire et sans serveur, comme la session.
      storage: demoNotes ? MemoryDailyNotesStorage() : FileDailyNotesStorage(),
      repository: demoNotes
          ? null
          : HttpDailyNoteRepository(apiClient: _apiClient),
      accessToken: _sessionController.accessTokenForApi,
    );
    // Heure du rappel du soir : réglée dans les paramètres.
    _settingsController.addListener(_applyNoteReminderTime);
    _agendaRepository = _buildAgendaRepository();
    _classAnnouncementRepository = _buildClassAnnouncementRepository();
    _apprenticeshipRepository = _buildApprenticeshipRepository();
    _classManagementRepository = _buildClassManagementRepository();
    _classResourceRepository = _buildClassResourceRepository();
    _dashboardRepository = _buildDashboardRepository();
    _appPreferencesRepository = _buildAppPreferencesRepository();
    _notificationPreferencesRepository =
        _buildNotificationPreferencesRepository();
    _courseRepository = _buildCourseRepository();
    _examRepository = _buildExamRepository();
    _feedbackRepository = _useDemoRepository(_useDemoAuthOverride)
        ? const DemoFeedbackRepository()
        : HttpFeedbackRepository(apiClient: _apiClient);
    _pushNotifications = PushNotificationService(
      sessionController: _sessionController,
      deviceRepository: HttpNotificationDeviceRepository(apiClient: _apiClient),
      // Les comptes de démonstration n'existent pas côté API.
      firebaseOptions: _useDemoRepository(_useDemoAuthOverride)
          ? null
          : FirebaseConfig.currentPlatform,
    );
    _sessionController.beforeLogout = _pushNotifications.unregister;
    _reminderSync = ReminderSync(
      sessionController: _sessionController,
      settingsController: _settingsController,
      courseRepository: _courseRepository,
      agendaRepository: _agendaRepository,
      scheduler: _notificationScheduler,
      deliveredByPush: () => _pushNotifications.isRegistered,
      localReminders: () => [
        if (_settingsController.dailyNoteReminderEnabled)
          ?_dailyNotesController.eveningReminder(DateTime.now()),
      ],
      autoSync: !_useDemoRepository(_useDemoAgendaOverride),
    );
    // Connexion, déconnexion ou changement de compte : on reprogramme.
    _sessionController.addListener(_syncRemindersOnSessionChange);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_pushNotifications.start());
    unawaited(_sessionController.restoreSession());
    unawaited(_settingsController.restore());
    unawaited(_companyContactsController.restore());
    unawaited(_companyDocumentsController.restore());
    unawaited(_dailyNotesController.restore());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_sessionController, _settingsController]),
      builder: (context, _) {
        return AppScope(
          sessionController: _sessionController,
          settingsController: _settingsController,
          agendaRepository: _agendaRepository,
          classAnnouncementRepository: _classAnnouncementRepository,
          apprenticeshipRepository: _apprenticeshipRepository,
          classManagementRepository: _classManagementRepository,
          classResourceRepository: _classResourceRepository,
          companyContactsController: _companyContactsController,
          companyDocumentsController: _companyDocumentsController,
          dailyNotesController: _dailyNotesController,
          dashboardRepository: _dashboardRepository,
          appPreferencesRepository: _appPreferencesRepository,
          notificationPreferencesRepository: _notificationPreferencesRepository,
          notificationScheduler: _notificationScheduler,
          courseRepository: _courseRepository,
          examRepository: _examRepository,
          feedbackRepository: _feedbackRepository,
          reminderSync: _reminderSync,
          child: MaterialApp(
            title: 'Swikko',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: _settingsController.themeMode,
            // Calendriers, sélecteurs d'heure et libellés système en français.
            locale: const Locale('fr', 'FR'),
            supportedLocales: const [Locale('fr', 'FR')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: _sessionController.status == SessionStatus.checkingSession
                ? const _SplashPage()
                : _sessionController.isSignedIn
                ? const MainShell()
                : const LoginPage(),
          ),
        );
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Au retour dans l'app, la classe a pu ajouter ou déplacer des cours.
    if (state != AppLifecycleState.resumed) return;
    _reminderSync.requestSync();
    // Notes écrites sur un autre appareil, ou restées en attente hors ligne.
    unawaited(_dailyNotesController.sync());
  }

  void _syncRemindersOnSessionChange() {
    final userId = _sessionController.session?.user.id;
    if (_sessionController.status == SessionStatus.checkingSession ||
        userId == _syncedUserId) {
      return;
    }
    _syncedUserId = userId;
    _reminderSync.requestSync();
    // Le carnet suit le compte : vidé à la déconnexion, synchronisé ensuite.
    unawaited(_dailyNotesController.attachUser(userId));
  }

  void _applyNoteReminderTime() {
    _dailyNotesController.reviewMinutes =
        _settingsController.dailyNoteReminderMinutes;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionController.removeListener(_syncRemindersOnSessionChange);
    _settingsController.removeListener(_applyNoteReminderTime);
    _sessionController.dispose();
    _settingsController.dispose();
    _companyContactsController.dispose();
    _companyDocumentsController.dispose();
    _dailyNotesController.dispose();
    if (_notificationScheduler is ChangeNotifier) {
      (_notificationScheduler as ChangeNotifier).dispose();
    }
    super.dispose();
  }

  AuthRepository _buildAuthRepository() {
    final useDemoAuth = _useDemoRepository(_useDemoAuthOverride);

    if (useDemoAuth) return const DemoAuthRepository();

    // Client séparé, sans renouvellement automatique : le renouvellement passe
    // lui-même par ce dépôt.
    return HttpAuthRepository(
      apiClient: ApiClient(baseUrl: ApiConfig.baseUrlFor(widget.environment)),
    );
  }

  DashboardRepository _buildDashboardRepository() {
    final useDemoDashboard = _useDemoRepository(_useDemoDashboardOverride);

    if (useDemoDashboard) return const DemoDashboardRepository();

    return HttpDashboardRepository(apiClient: _apiClient);
  }

  AgendaRepository _buildAgendaRepository() {
    final useDemoAgenda = _useDemoRepository(_useDemoAgendaOverride);

    if (useDemoAgenda) return const DemoAgendaRepository();

    return HttpAgendaRepository(apiClient: _apiClient);
  }

  ApprenticeshipRepository _buildApprenticeshipRepository() {
    final useDemoApprenticeships = _useDemoRepository(
      _useDemoApprenticeshipsOverride,
    );

    if (useDemoApprenticeships) return const DemoApprenticeshipRepository();

    return HttpApprenticeshipRepository(apiClient: _apiClient);
  }

  ClassAnnouncementRepository _buildClassAnnouncementRepository() {
    final useDemoAnnouncements = _useDemoRepository(
      _useDemoAnnouncementsOverride,
    );

    if (useDemoAnnouncements) return const DemoClassAnnouncementRepository();

    return HttpClassAnnouncementRepository(apiClient: _apiClient);
  }

  CourseRepository _buildCourseRepository() {
    final useDemoCourses = _useDemoRepository(_useDemoCoursesOverride);

    if (useDemoCourses) return const DemoCourseRepository();

    return HttpCourseRepository(apiClient: _apiClient);
  }

  ExamRepository _buildExamRepository() {
    if (_useDemoRepository(_useDemoExamsOverride)) {
      return const DemoExamRepository();
    }

    return HttpExamRepository(apiClient: _apiClient);
  }

  ClassManagementRepository _buildClassManagementRepository() {
    final useDemoClassManagement = _useDemoRepository(
      _useDemoClassManagementOverride,
    );

    if (useDemoClassManagement) return const DemoClassManagementRepository();

    return HttpClassManagementRepository(apiClient: _apiClient);
  }

  ClassResourceRepository _buildClassResourceRepository() {
    final useDemoClassResources = _useDemoRepository(
      _useDemoClassResourcesOverride,
    );

    if (useDemoClassResources) return const DemoClassResourceRepository();

    return HttpClassResourceRepository(apiClient: _apiClient);
  }

  NotificationPreferencesRepository _buildNotificationPreferencesRepository() {
    final useDemoNotificationPreferences = _useDemoRepository(
      _useDemoNotificationPreferencesOverride,
    );

    if (useDemoNotificationPreferences) {
      return const DemoNotificationPreferencesRepository();
    }

    return HttpNotificationPreferencesRepository(apiClient: _apiClient);
  }

  AppPreferencesRepository _buildAppPreferencesRepository() {
    final useDemoAppPreferences = _useDemoRepository(
      _useDemoAppPreferencesOverride,
    );

    if (useDemoAppPreferences) return const DemoAppPreferencesRepository();

    return HttpAppPreferencesRepository(apiClient: _apiClient);
  }

  SessionStorage _buildSessionStorage() {
    final useDemoAuth = _useDemoRepository(_useDemoAuthOverride);

    // Demo mode stays ephemeral so fake sessions do not pollute secure storage.
    if (useDemoAuth) return MemorySessionStorage();

    return SecureSessionStorage();
  }

  bool _useDemoRepository(String override) {
    if (override.isEmpty) {
      return widget.environment.useDemoRepositoriesByDefault;
    }
    return override.toLowerCase() == 'true';
  }
}

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
