part of 'profile_page.dart';

/// Paramètres : notifications, ne pas déranger, espace pro, apparence et
/// compte. Séparés du profil pour garder celui-ci court.
class ProfileSettingsPage extends StatelessWidget {
  const ProfileSettingsPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const ProfileSettingsPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appScope = AppScope.of(context);
    final sessionController = appScope.sessionController;
    final settingsController = appScope.settingsController;

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: AnimatedBuilder(
        animation: settingsController,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
          children: [
            const _SettingsGroupTitle(title: 'Notifications'),
            _SettingsGroup(
              children: [
                _SwitchSettingLine(
                  icon: Icons.notifications_active_outlined,
                  iconColor: AppColors.sky,
                  title: 'Notifications de cours',
                  subtitle: 'Recevoir les rappels avant les cours.',
                  value: settingsController.courseNotificationsEnabled,
                  onChanged: (value) {
                    settingsController.setCourseNotificationsEnabled(value);
                    _syncNotificationPreferences(context);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                  child: DropdownButtonFormField<int>(
                    initialValue: settingsController.courseReminderMinutes,
                    decoration: const InputDecoration(
                      labelText: 'Rappel avant un cours',
                      prefixIcon: Icon(Icons.schedule_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('À l’heure')),
                      DropdownMenuItem(value: 5, child: Text('5 minutes')),
                      DropdownMenuItem(value: 10, child: Text('10 minutes')),
                      DropdownMenuItem(value: 15, child: Text('15 minutes')),
                      DropdownMenuItem(value: 30, child: Text('30 minutes')),
                      DropdownMenuItem(value: 60, child: Text('1 heure')),
                    ],
                    onChanged: settingsController.courseNotificationsEnabled
                        ? (value) {
                            if (value == null) return;
                            settingsController.setCourseReminderMinutes(value);
                            _syncNotificationPreferences(context);
                          }
                        : null,
                  ),
                ),
                _SwitchSettingLine(
                  icon: Icons.assignment_outlined,
                  iconColor: AppColors.mint,
                  title: 'Notifications de devoirs',
                  subtitle: 'Recevoir les rappels avant les rendus.',
                  value: settingsController.homeworkNotificationsEnabled,
                  onChanged: (value) {
                    settingsController.setHomeworkNotificationsEnabled(value);
                    _syncNotificationPreferences(context);
                  },
                ),
                if (!settingsController.hasCompany)
                  _SwitchSettingLine(
                    icon: Icons.business_center_outlined,
                    iconColor: AppColors.greenSoft,
                    title: 'Notifications alternance',
                    subtitle: 'Recevoir les rappels liés à ta recherche.',
                    value:
                        settingsController.apprenticeshipNotificationsEnabled,
                    onChanged: (value) {
                      settingsController.setApprenticeshipNotificationsEnabled(
                        value,
                      );
                      _syncNotificationPreferences(context);
                    },
                  ),
              ],
            ),
            const _SettingsGroupTitle(title: 'Ne pas déranger'),
            _QuietHoursGroup(settingsController: settingsController),
            const _ScheduledRemindersCard(),
            const SizedBox(height: 12),
            const _SettingsGroupTitle(title: 'Espace pro'),
            _SettingsGroup(
              children: [
                _SwitchSettingLine(
                  key: const ValueKey('has-company-switch-line'),
                  switchKey: const ValueKey('has-company-switch'),
                  icon: Icons.work_outline,
                  iconColor: AppColors.greenSoft,
                  title: 'J’ai une entreprise',
                  subtitle:
                      'Transforme l’onglet Alternance en espace Entreprise.',
                  value: settingsController.hasCompany,
                  onChanged: (value) {
                    settingsController.setHasCompany(value);
                    _syncAppPreferences(context);
                  },
                ),
              ],
            ),
            const _SettingsGroupTitle(title: 'Coin note'),
            _SettingsGroup(
              children: [
                _SwitchSettingLine(
                  switchKey: const ValueKey('daily-notes-switch'),
                  icon: Icons.edit_note,
                  iconColor: AppColors.evaluationSoft,
                  title: 'Notes du jour sur l’accueil',
                  subtitle:
                      'Un bouton pour noter vite une idée dans la journée.',
                  value: settingsController.dailyNotesEnabled,
                  onChanged: (value) {
                    settingsController.setDailyNotesEnabled(value);
                    AppScope.of(context).reminderSync.requestSync();
                  },
                ),
                if (settingsController.dailyNotesEnabled)
                  _SwitchSettingLine(
                    switchKey: const ValueKey('daily-note-reminder-switch'),
                    icon: Icons.nightlight_outlined,
                    iconColor: AppColors.evaluationSoft,
                    title: 'Rappel du soir',
                    subtitle:
                        'Relire la note du jour à ${QuietHours.formatTime(settingsController.dailyNoteReminderMinutes)}.',
                    value: settingsController.dailyNoteReminderEnabled,
                    onChanged: (value) {
                      settingsController.setDailyNoteReminderEnabled(value);
                      AppScope.of(context).reminderSync.requestSync();
                    },
                  ),
                if (settingsController.dailyNoteReminderEnabled)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: OutlinedButton.icon(
                      key: const ValueKey('daily-note-reminder-time'),
                      onPressed: () =>
                          _pickNoteReminderTime(context, settingsController),
                      icon: const Icon(Icons.schedule_outlined, size: 18),
                      label: Text(
                        'Rappel à ${QuietHours.formatTime(settingsController.dailyNoteReminderMinutes)}',
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const _SettingsGroupTitle(title: 'Application'),
            _SettingsGroup(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: DropdownButtonFormField<ThemeMode>(
                    initialValue: settingsController.themeMode,
                    decoration: const InputDecoration(
                      labelText: 'Apparence',
                      prefixIcon: Icon(Icons.contrast),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text('Système'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text('Clair'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text('Sombre'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      settingsController.setThemeMode(value);
                      _syncAppPreferences(context);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8D5C66),
                backgroundColor: AppColors.roseSoft,
                side: const BorderSide(color: Color(0xFFD9BDC3)),
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                // Retour à l'accueil d'abord : l'écran de connexion remplace
                // l'app, cette page ne doit pas rester par-dessus.
                Navigator.of(context).popUntil((route) => route.isFirst);
                sessionController.logout();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Se déconnecter'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB35C68),
                minimumSize: const Size.fromHeight(42),
              ),
              onPressed: () => _confirmDeleteAccount(context),
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Supprimer mon compte'),
            ),

            const SizedBox(height: 12),
            Text(
              'StudyFlow Pro · version étudiante',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.sfMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _pickNoteReminderTime(
  BuildContext context,
  AppSettingsController settings,
) async {
  final current = settings.dailyNoteReminderMinutes;
  final picked = await StudyFlowPickers.pickTime(
    context,
    initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
  );
  if (picked == null || !context.mounted) return;
  settings.setDailyNoteReminderMinutes(picked.hour * 60 + picked.minute);
  AppScope.of(context).reminderSync.requestSync();
}

/// Entrée vers les paramètres, en bas du profil.
class _SettingsEntry extends StatelessWidget {
  const _SettingsEntry({required this.onOpen, required this.quietHours});

  final VoidCallback onOpen;
  final QuietHours quietHours;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final status = quietHours.isMuted(now)
        ? 'Notifications en pause jusqu’à ${_formatMute(quietHours.mutedUntil!)}'
        : quietHours.enabled
        ? 'Ne pas déranger de ${QuietHours.formatTime(quietHours.startMinutes)} à ${QuietHours.formatTime(quietHours.endMinutes)}'
        : 'Notifications, ne pas déranger, apparence, compte';

    return ProtoCard(
      key: const ValueKey('settings-entry'),
      onTap: onOpen,
      child: Row(
        children: [
          const ProtoIconBox(icon: Icons.settings_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paramètres',
                  style: TextStyle(
                    color: context.sfText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                ProtoMutedText(status, maxLines: 2),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.sfChevron),
        ],
      ),
    );
  }
}

String _formatMute(DateTime until) {
  final local = until.toLocal();
  final today = DateUtils.dateOnly(DateTime.now());
  final time = QuietHours.formatTime(local.hour * 60 + local.minute);
  return DateUtils.isSameDay(local, today)
      ? time
      : '${StudyFlowFormat.shortDay(local)} $time';
}

/// Plage calme quotidienne et pause ponctuelle. Synchronisées avec le serveur
/// pour que les notifications push respectent aussi ces choix.
class _QuietHoursGroup extends StatelessWidget {
  const _QuietHoursGroup({required this.settingsController});

  final AppSettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    final quiet = settingsController.quietHours;
    final now = DateTime.now();
    final muted = quiet.isMuted(now);

    void update(QuietHours value) {
      settingsController.setQuietHours(value);
      _syncNotificationPreferences(context);
      AppScope.of(context).reminderSync.requestSync();
    }

    Future<void> pick({required bool start}) async {
      final current = start ? quiet.startMinutes : quiet.endMinutes;
      final picked = await StudyFlowPickers.pickTime(
        context,
        initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      );
      if (picked == null || !context.mounted) return;
      final minutes = picked.hour * 60 + picked.minute;
      update(
        start
            ? quiet.copyWith(startMinutes: minutes)
            : quiet.copyWith(endMinutes: minutes),
      );
    }

    void pause(DateTime until) => update(quiet.copyWith(mutedUntil: until));

    final tomorrowMorning = DateTime(now.year, now.month, now.day + 1, 8);

    return _SettingsGroup(
      children: [
        _SwitchSettingLine(
          switchKey: const ValueKey('quiet-hours-switch'),
          icon: Icons.bedtime_outlined,
          iconColor: AppColors.blueGray,
          title: 'Plage calme chaque jour',
          subtitle: quiet.enabled
              ? 'Aucune notification de ${QuietHours.formatTime(quiet.startMinutes)} à ${QuietHours.formatTime(quiet.endMinutes)}.'
              : 'Coupe les notifications la nuit, par exemple.',
          value: quiet.enabled,
          onChanged: (value) => update(quiet.copyWith(enabled: value)),
        ),
        if (quiet.enabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('quiet-hours-start'),
                    onPressed: () => pick(start: true),
                    icon: const Icon(Icons.nights_stay_outlined, size: 18),
                    label: Text(
                      'De ${QuietHours.formatTime(quiet.startMinutes)}',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('quiet-hours-end'),
                    onPressed: () => pick(start: false),
                    icon: const Icon(Icons.wb_sunny_outlined, size: 18),
                    label: Text('À ${QuietHours.formatTime(quiet.endMinutes)}'),
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: context.sfLine)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProtoIconBox(
                    icon: muted
                        ? Icons.notifications_paused
                        : Icons.notifications_paused_outlined,
                    backgroundColor: muted
                        ? context.sfEvaluationSoft
                        : AppColors.sandSoft,
                    foregroundColor: muted
                        ? context.sfEvaluation
                        : AppColors.petrol,
                    size: 34,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          muted
                              ? 'En pause jusqu’à ${_formatMute(quiet.mutedUntil!)}'
                              : 'Mettre en pause',
                          style: TextStyle(
                            color: context.sfText,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          muted
                              ? 'Aucune notification d’ici là.'
                              : 'Plus aucune notification pendant un moment.',
                          style: TextStyle(
                            color: context.sfIsDark
                                ? Colors.white70
                                : AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (muted)
                    FilledButton.tonalIcon(
                      key: const ValueKey('quiet-resume'),
                      onPressed: () => update(quiet.copyWith(clearMute: true)),
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('Reprendre maintenant'),
                    )
                  else ...[
                    ActionChip(
                      key: const ValueKey('quiet-pause-1h'),
                      label: const Text('1 heure'),
                      onPressed: () => pause(now.add(const Duration(hours: 1))),
                    ),
                    ActionChip(
                      label: const Text('3 heures'),
                      onPressed: () => pause(now.add(const Duration(hours: 3))),
                    ),
                    ActionChip(
                      label: const Text('Jusqu’à demain 8 h'),
                      onPressed: () => pause(tomorrowMorning),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
