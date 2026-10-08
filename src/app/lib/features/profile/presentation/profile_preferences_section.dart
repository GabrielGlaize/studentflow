part of 'profile_page.dart';

class _ScheduledRemindersCard extends StatefulWidget {
  const _ScheduledRemindersCard();

  @override
  State<_ScheduledRemindersCard> createState() =>
      _ScheduledRemindersCardState();
}

class _ScheduledRemindersCardState extends State<_ScheduledRemindersCard> {
  static const _planner = ReminderPlanner();

  Future<List<ScheduledReminder>>? _future;
  Listenable? _settingsListenable;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settingsController = AppScope.of(context).settingsController;
    if (_settingsListenable != settingsController) {
      _settingsListenable?.removeListener(_reload);
      _settingsListenable = settingsController..addListener(_reload);
    }

    _future ??= _loadAndSchedule();
  }

  @override
  void dispose() {
    _settingsListenable?.removeListener(_reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ScheduledReminder>>(
      future: _future,
      builder: (context, snapshot) {
        final reminders = snapshot.data ?? const <ScheduledReminder>[];

        return ProtoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProtoSectionHeading(
                overline: 'Notifications',
                title: 'Rappels prévus',
                trailing: IconButton(
                  tooltip: 'Actualiser',
                  onPressed: () {
                    setState(() {
                      _future = _loadAndSchedule();
                    });
                  },
                  icon: const Icon(Icons.refresh_outlined),
                ),
              ),
              const SizedBox(height: 8),
              if (snapshot.connectionState != ConnectionState.done)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: LinearProgressIndicator(),
                )
              else if (reminders.isEmpty)
                const ProtoMutedText(
                  'Aucun rappel futur avec les réglages actuels.',
                )
              else
                ...reminders.take(3).map(_ReminderPreviewLine.new),
              const SizedBox(height: 8),
              const ProtoMutedText(
                'Les rappels sont programmés localement sur ton téléphone quand les autorisations iOS/Android sont acceptées.',
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<ScheduledReminder>> _loadAndSchedule() async {
    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    final today = DateTime.now();
    final weekStart = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - DateTime.monday));

    final courses = await appScope.courseRepository.listCourses(
      from: weekStart,
      to: DateTime(weekStart.year, weekStart.month, weekStart.day + 6),
      accessToken: accessToken,
    );
    final agenda = await appScope.agendaRepository.getAgenda(
      taskCategory: 'school',
      accessToken: accessToken,
    );
    final reminders = _planner.plan(
      courses: courses,
      homework: agenda.homework,
      settings: appScope.settingsController.currentSettings,
    );

    await appScope.notificationScheduler.replaceAll(reminders);
    return reminders;
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = _loadAndSchedule();
    });
  }
}

class _ReminderPreviewLine extends StatelessWidget {
  const _ReminderPreviewLine(this.reminder);

  final ScheduledReminder reminder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProtoIconBox(
            icon: reminder.type == ReminderType.course
                ? Icons.notifications_active_outlined
                : Icons.assignment_outlined,
            backgroundColor: reminder.type == ReminderType.course
                ? AppColors.primarySoft
                : AppColors.greenSoft,
            size: 34,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  style: TextStyle(
                    color: context.sfText,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatDateTime(reminder.scheduledAt)} · ${reminder.body}',
                  style: TextStyle(
                    color: context.sfMuted,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month à $hour:$minute';
  }
}

class _AppPreferencesLoader extends StatefulWidget {
  const _AppPreferencesLoader();

  @override
  State<_AppPreferencesLoader> createState() => _AppPreferencesLoaderState();
}

class _AppPreferencesLoaderState extends State<_AppPreferencesLoader> {
  bool _hasLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasLoaded) return;
    _hasLoaded = true;
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();

  Future<void> _load() async {
    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      final preferences = await appScope.appPreferencesRepository
          .getPreferences(accessToken: accessToken);
      if (!mounted) return;
      appScope.settingsController.applyAppPreferences(
        themeMode: preferences.themeMode,
        hasCompany: preferences.hasCompany,
        companyName: preferences.companyName,
      );
    } on Exception {
      // Local settings remain usable if the API is unavailable.
    }
  }
}

class _NotificationPreferencesLoader extends StatefulWidget {
  const _NotificationPreferencesLoader();

  @override
  State<_NotificationPreferencesLoader> createState() =>
      _NotificationPreferencesLoaderState();
}

class _NotificationPreferencesLoaderState
    extends State<_NotificationPreferencesLoader> {
  bool _hasLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasLoaded) return;
    _hasLoaded = true;
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();

  Future<void> _load() async {
    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      final preferences = await appScope.notificationPreferencesRepository
          .getPreferences(accessToken: accessToken);
      if (!mounted) return;
      appScope.settingsController.applyNotificationPreferences(
        coursesEnabled: preferences.coursesEnabled,
        homeworkEnabled: preferences.homeworkEnabled,
        apprenticeshipsEnabled: preferences.apprenticeshipsEnabled,
        courseReminderMinutes: preferences.courseReminderMinutes,
      );
    } on Exception {
      // Local settings remain usable if the API is unavailable.
    }
  }
}

void _syncAppPreferences(BuildContext context) {
  final appScope = AppScope.of(context);
  final settings = appScope.settingsController;

  unawaited(() async {
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      await appScope.appPreferencesRepository.updatePreferences(
        preferences: RemoteAppPreferences(
          themeMode: settings.themeMode,
          hasCompany: settings.hasCompany,
          companyName: settings.companyName,
          professionalMode: settings.hasCompany
              ? ProfessionalMode.company
              : ProfessionalMode.apprenticeship,
        ),
        accessToken: accessToken,
      );
    } on Exception {
      // The local preference is already saved; syncing can be retried later.
    }
  }());
}

void _syncNotificationPreferences(BuildContext context) {
  final appScope = AppScope.of(context);
  final settings = appScope.settingsController;

  unawaited(() async {
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      await appScope.notificationPreferencesRepository.updatePreferences(
        preferences: NotificationPreferences(
          coursesEnabled: settings.courseNotificationsEnabled,
          homeworkEnabled: settings.homeworkNotificationsEnabled,
          apprenticeshipsEnabled: settings.apprenticeshipNotificationsEnabled,
          courseReminderMinutes: settings.courseReminderMinutes,
        ),
        accessToken: accessToken,
      );
    } on Exception {
      // The local preference is already saved; syncing can be retried later.
    }
  }());
}
