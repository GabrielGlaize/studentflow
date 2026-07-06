import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/features/classes/domain/class_models.dart';
import 'package:studyflow_app/features/classes/domain/class_resource_models.dart';
import 'package:studyflow_app/features/company/application/company_documents_controller.dart';
import 'package:studyflow_app/features/notifications/application/reminder_planner.dart';
import 'package:studyflow_app/features/notifications/domain/notification_models.dart';
import 'package:studyflow_app/features/profile/domain/app_preferences.dart';
import 'package:studyflow_app/features/profile/domain/notification_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final appScope = AppScope.of(context);
    final sessionController = appScope.sessionController;
    final settingsController = appScope.settingsController;
    final documentsController = appScope.companyDocumentsController;
    final user = sessionController.session?.user;

    return AnimatedBuilder(
      animation: Listenable.merge([settingsController, documentsController]),
      builder: (context, _) {
        CompanyDocument? studentCard;
        for (final document in documentsController.documents) {
          if (document.scope == 'student-card') {
            studentCard = document;
            break;
          }
        }
        final studentCardId = studentCard?.id;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 112),
            children: [
              Text(
                'Profil et réglages',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: isDark ? Colors.white : AppColors.petrol,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 14),
              _ProfileCard(
                name: user?.displayName ?? 'Utilisateur',
                email: user?.email ?? 'Session démo',
                isDelegate: user?.isDelegate == true,
              ),
              _StudentCardSection(
                document: studentCard,
                isDelegate: user?.isDelegate == true,
                onImport: () => _openStudentCardSheet(context),
                onOpen: studentCard == null
                    ? null
                    : () => _openStudentCard(context, studentCard!),
                onDelete: studentCardId == null
                    ? null
                    : () => documentsController.deleteDocument(studentCardId),
              ),
              const _AppPreferencesLoader(),
              const _NotificationPreferencesLoader(),
              _ClassManagementSection(isDelegate: user?.isDelegate == true),
              const SizedBox(height: 4),
              const _SettingsGroupTitle(title: 'Préférences'),
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
                              settingsController.setCourseReminderMinutes(
                                value,
                              );
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
                        settingsController
                            .setApprenticeshipNotificationsEnabled(value);
                        _syncNotificationPreferences(context);
                      },
                    ),
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
              const _ScheduledRemindersCard(),
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
                onPressed: sessionController.logout,
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
                style: TextStyle(color: context.sfMuted, fontSize: 8),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openStudentCardSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const _StudentCardImportSheet(),
    );
  }

  Future<void> _openStudentCard(
    BuildContext context,
    CompanyDocument document,
  ) async {
    final localPath = document.filePath?.trim();
    final link = document.link?.trim();
    final uri = localPath != null && localPath.isNotEmpty
        ? Uri.file(localPath)
        : link != null && link.isNotEmpty
        ? Uri.tryParse(link)
        : null;

    if (uri == null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Carte enregistrée, mais aucun fichier ou lien ne peut être ouvert.',
            ),
          ),
        );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Impossible d’ouvrir la carte.')),
        );
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer le compte ?'),
        content: const Text(
          'Ton compte sera désactivé et tu seras déconnecté. Cette action est réservée aux tests pour l’instant.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB35C68),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !context.mounted) return;

    try {
      await AppScope.of(context).sessionController.deleteAccount();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Compte supprimé.')));
    } on Exception catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

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
      to: weekStart.add(const Duration(days: 6)),
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
                    fontSize: 10,
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

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.email,
    required this.isDelegate,
  });

  final String name;
  final String email;
  final bool isDelegate;

  @override
  Widget build(BuildContext context) {
    return ProtoCard(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              gradient: const LinearGradient(
                colors: [Color(0xFF17657A), AppColors.petrol],
              ),
            ),
            child: Center(
              child: Text(
                _initials(name),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: context.sfText,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: TextStyle(color: context.sfMuted, fontSize: 9),
                ),
                if (isDelegate) ...[
                  const SizedBox(height: 6),
                  const ProtoChip(label: 'Délégué'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }
}

class _StudentCardSection extends StatelessWidget {
  const _StudentCardSection({
    required this.document,
    required this.isDelegate,
    required this.onImport,
    required this.onOpen,
    required this.onDelete,
  });

  final CompanyDocument? document;
  final bool isDelegate;
  final VoidCallback onImport;
  final VoidCallback? onOpen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final hasCard = document != null;

    return ProtoCard(
      borderColor: hasCard ? AppColors.mint : AppColors.line,
      backgroundColor: hasCard ? const Color(0xFFEFFFFB) : Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProtoIconBox(
            icon: hasCard ? Icons.badge_outlined : Icons.add_photo_alternate,
            backgroundColor: hasCard ? AppColors.mint : AppColors.primarySoft,
            foregroundColor: AppColors.petrol,
            size: 45,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProtoOverline(isDelegate ? 'Accès rapide' : 'Carte étudiante'),
                const SizedBox(height: 3),
                Text(
                  hasCard
                      ? 'Carte étudiante enregistrée'
                      : 'Importer ma carte étudiante',
                  style: TextStyle(
                    color: context.sfText,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                ProtoMutedText(
                  hasCard
                      ? [
                          if (document!.fileName != null) document!.fileName!,
                          if (document!.link != null) document!.link!,
                          if (document!.note != null) document!.note!,
                        ].where((value) => value.trim().isNotEmpty).join(' · ')
                      : 'Ajoute une photo, un lien Drive ou une note pour la retrouver vite.',
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (hasCard)
                      FilledButton.icon(
                        onPressed: onOpen,
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text('Voir'),
                      ),
                    OutlinedButton.icon(
                      onPressed: onImport,
                      icon: Icon(
                        hasCard ? Icons.edit_outlined : Icons.upload_outlined,
                        size: 16,
                      ),
                      label: Text(hasCard ? 'Modifier' : 'Importer'),
                    ),
                    if (hasCard && onDelete != null)
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Retirer'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentCardImportSheet extends StatefulWidget {
  const _StudentCardImportSheet();

  @override
  State<_StudentCardImportSheet> createState() =>
      _StudentCardImportSheetState();
}

class _StudentCardImportSheetState extends State<_StudentCardImportSheet> {
  final _formKey = GlobalKey<FormState>();
  final _linkController = TextEditingController();
  final _noteController = TextEditingController();
  PlatformFile? _selectedFile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ProtoSectionHeading(
              overline: 'Profil',
              title: 'Carte étudiante',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _linkController,
              decoration: const InputDecoration(
                labelText: 'Lien ou emplacement optionnel',
                prefixIcon: Icon(Icons.link_outlined),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickStudentCard,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                _selectedFile == null
                    ? 'Importer photo ou fichier'
                    : 'Fichier : ${_selectedFile!.name}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note optionnelle',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Enregistrer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final controller = AppScope.of(context).companyDocumentsController;
    for (final document in controller.documents) {
      if (document.scope == 'student-card') {
        controller.deleteDocument(document.id);
      }
    }
    controller.addDocument(
      title: 'Carte étudiante',
      kind: 'Carte étudiante',
      scope: 'student-card',
      link: _linkController.text,
      note: _noteController.text,
      fileName: _selectedFile?.name,
      filePath: _selectedFile?.path,
      fileSizeBytes: _selectedFile?.size,
    );

    Navigator.pop(context);
  }

  Future<void> _pickStudentCard() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
      type: FileType.image,
    );
    final files = result?.files;
    final file = files == null || files.isEmpty ? null : files.first;
    if (file == null || !mounted) return;
    setState(() {
      _selectedFile = file;
    });
  }

  @override
  void dispose() {
    _linkController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}

class _ClassManagementSection extends StatefulWidget {
  const _ClassManagementSection({required this.isDelegate});

  final bool isDelegate;

  @override
  State<_ClassManagementSection> createState() =>
      _ClassManagementSectionState();
}

class _ClassManagementSectionState extends State<_ClassManagementSection> {
  Future<_ClassManagementState>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ClassManagementState>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ProtoCard(
            child: ProtoStateCard(
              icon: Icons.school_outlined,
              title: 'Classe',
              message: 'Chargement de ta classe et des droits délégué.',
              compact: true,
            ),
          );
        }

        final state = snapshot.data;
        if (state?.currentClass == null) {
          return ProtoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ProtoStateCard(
                  icon: Icons.school_outlined,
                  title: 'Pas encore de classe',
                  message:
                      'Tu peux continuer à gérer ton alternance, ou demander à rejoindre une classe avec un code.',
                  compact: true,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openJoinClassSheet,
                  icon: const Icon(Icons.key_outlined),
                  label: const Text('Rejoindre une classe'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _openCreateClassSheet,
                  icon: const Icon(Icons.add_home_work_outlined),
                  label: const Text('Créer ma classe'),
                ),
              ],
            ),
          );
        }

        final currentClass = state!.currentClass!;
        final isDelegate = widget.isDelegate || currentClass.isDelegate;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SettingsGroupTitle(
              title: isDelegate ? 'Gestion de classe' : 'Ma classe',
            ),
            if (isDelegate)
              ProtoGradientCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ProtoOverline(
                            'Code classe',
                            color: Colors.white70,
                          ),
                        ),
                        ProtoChip(
                          label: 'DÉLÉGUÉ',
                          backgroundColor: AppColors.mint,
                          foregroundColor: AppColors.petrol,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      'Code classe : ${currentClass.accessCode ?? 'AUCUN'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${currentClass.name} · ${currentClass.schoolYear}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'À partager seulement aux élèves de la classe. Le délégué approuve ensuite les demandes.',
                      style: TextStyle(
                        color: Color(0xDFFFFFFF),
                        fontSize: 11,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                          onPressed: currentClass.accessCode == null
                              ? null
                              : () => _copyAccessCode(currentClass.accessCode!),
                          icon: const Icon(Icons.copy_outlined, size: 16),
                          label: const Text('Copier'),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                          onPressed: () => _openClassEditSheet(currentClass),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Modifier'),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                          onPressed: _regenerateAccessCode,
                          icon: const Icon(Icons.refresh_outlined, size: 16),
                          label: const Text('Nouveau code'),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              ProtoCard(
                child: ProtoStateCard(
                  icon: Icons.groups_outlined,
                  title: currentClass.name,
                  message:
                      '${currentClass.schoolYear} · Tu peux consulter les membres de ta classe.',
                  compact: true,
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _leaveClass,
                icon: const Icon(Icons.exit_to_app_outlined, size: 17),
                label: const Text('Quitter la classe'),
              ),
            ),
            if (isDelegate)
              ProtoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ProtoSectionHeading(
                      overline: 'Délégué',
                      title: 'Demandes à approuver',
                    ),
                    const SizedBox(height: 10),
                    if (state.pendingRequests.isEmpty)
                      const ProtoMutedText('Aucune demande en attente.')
                    else
                      ...state.pendingRequests.map(
                        (request) => _PendingRequestRow(
                          request: request,
                          onApprove: () => _approve(request),
                          onReject: () => _reject(request),
                        ),
                      ),
                  ],
                ),
              ),
            _ClassMembersCard(
              members: state.members,
              isDelegate: isDelegate,
              onMakeDelegate: _makeDelegate,
              onRemoveMember: _removeMember,
              onLeaveDelegateRole: _leaveDelegateRole,
            ),
            _ClassResourcesCard(
              subjects: state.subjects,
              teachers: state.teachers,
              isDelegate: isDelegate,
              onAddSubject: _openSubjectSheet,
              onAddTeacher: _openTeacherSheet,
              onDeleteSubject: _deleteSubject,
              onDeleteTeacher: _deleteTeacher,
            ),
          ],
        );
      },
    );
  }

  Future<_ClassManagementState> _load() async {
    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    final currentClass = await appScope.classManagementRepository
        .getCurrentClass(accessToken: accessToken);
    final isDelegate = widget.isDelegate || currentClass?.isDelegate == true;
    final pendingRequestsFuture = isDelegate
        ? appScope.classManagementRepository.listPendingRequests(
            accessToken: accessToken,
          )
        : Future.value(<PendingMembershipRequest>[]);
    final membersFuture = currentClass != null
        ? appScope.classManagementRepository.listMembers(
            accessToken: accessToken,
          )
        : Future.value(<ClassMember>[]);
    final subjectsFuture = currentClass == null
        ? Future.value(<ClassSubject>[])
        : appScope.classResourceRepository.listSubjects(
            accessToken: accessToken,
          );
    final teachersFuture = currentClass == null
        ? Future.value(<ClassTeacher>[])
        : appScope.classResourceRepository.listTeachers(
            accessToken: accessToken,
          );

    return _ClassManagementState(
      currentClass: currentClass,
      pendingRequests: await pendingRequestsFuture,
      members: await membersFuture,
      subjects: await subjectsFuture,
      teachers: await teachersFuture,
    );
  }

  Future<void> _copyAccessCode(String accessCode) async {
    await Clipboard.setData(ClipboardData(text: accessCode));

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Code classe copié.')));
  }

  Future<void> _openCreateClassSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const _CreateClassForCurrentUserSheet(),
    );

    if (created == true && mounted) {
      _showSnack('Classe créée. Tu es maintenant délégué.');
      setState(() => _future = _load());
    }
  }

  Future<void> _approve(PendingMembershipRequest request) async {
    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    await appScope.classManagementRepository.approveRequest(
      requestId: request.id,
      accessToken: accessToken,
    );

    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  Future<void> _makeDelegate(ClassMember member) async {
    final shouldConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nommer délégué ?'),
        content: Text('${member.displayName} pourra gérer la classe avec toi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Nommer'),
          ),
        ],
      ),
    );
    if (shouldConfirm != true || !mounted) return;

    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    await appScope.classManagementRepository.makeDelegate(
      memberId: member.id,
      accessToken: accessToken,
    );

    if (!mounted) return;
    _showSnack('Délégué ajouté.');
    setState(() => _future = _load());
  }

  Future<void> _removeMember(ClassMember member) async {
    final shouldConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer cet élève ?'),
        content: Text(
          '${member.displayName} ne verra plus les données de la classe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (shouldConfirm != true || !mounted) return;

    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    await appScope.classManagementRepository.removeMember(
      memberId: member.id,
      accessToken: accessToken,
    );

    if (!mounted) return;
    _showSnack('Élève retiré de la classe.');
    setState(() => _future = _load());
  }

  Future<void> _leaveDelegateRole() async {
    final shouldConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter le rôle délégué ?'),
        content: const Text(
          'Tu resteras élève de la classe. Un autre délégué doit déjà exister.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitter le rôle'),
          ),
        ],
      ),
    );
    if (shouldConfirm != true || !mounted) return;

    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    await appScope.classManagementRepository.leaveDelegateRole(
      accessToken: accessToken,
    );

    if (!mounted) return;
    _showSnack('Rôle délégué retiré.');
    setState(() => _future = _load());
  }

  Future<void> _leaveClass() async {
    final shouldConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter la classe ?'),
        content: const Text(
          'Tu ne verras plus les cours, devoirs, membres et messages de cette classe. Tu pourras rejoindre une autre classe ensuite.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    if (shouldConfirm != true || !mounted) return;

    try {
      final appScope = AppScope.of(context);
      final accessToken = await appScope.sessionController.accessTokenForApi();
      final session = await appScope.classManagementRepository.leaveClass(
        accessToken: accessToken,
      );
      await appScope.sessionController.replaceSession(session);

      if (!mounted) return;
      _showSnack('Tu as quitté la classe.');
      setState(() => _future = _load());
    } on Exception catch (error) {
      if (!mounted) return;
      _showSnack(error.toString());
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reject(PendingMembershipRequest request) async {
    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    await appScope.classManagementRepository.rejectRequest(
      requestId: request.id,
      accessToken: accessToken,
    );

    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openClassEditSheet(CurrentClassInfo currentClass) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _ClassEditSheet(currentClass: currentClass),
    );

    if (!mounted || updated != true) return;
    setState(() {
      _future = _load();
    });
  }

  Future<void> _regenerateAccessCode() async {
    final shouldRegenerate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Générer un nouveau code ?'),
        content: const Text(
          'L’ancien code ne permettra plus de rejoindre la classe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Générer'),
          ),
        ],
      ),
    );

    if (shouldRegenerate != true || !mounted) return;

    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    await appScope.classManagementRepository.regenerateAccessCode(
      accessToken: accessToken,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Nouveau code généré.')));
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openJoinClassSheet() async {
    final requested = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const _JoinClassSheet(),
    );

    if (!mounted || requested != true) return;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Demande envoyée. Un délégué doit l’approuver.'),
        ),
      );
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openSubjectSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const _CreateSubjectSheet(),
    );

    if (!mounted || created != true) return;
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openTeacherSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const _CreateTeacherSheet(),
    );

    if (!mounted || created != true) return;
    setState(() {
      _future = _load();
    });
  }

  Future<void> _deleteSubject(ClassSubject subject) async {
    final shouldDelete = await _confirmResourceDelete(
      title: 'Retirer cette matière ?',
      message:
          '“${subject.name}” ne sera plus proposée dans les nouveaux cours.',
    );
    if (shouldDelete != true || !mounted) return;

    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    await appScope.classResourceRepository.deleteSubject(
      subjectId: subject.id,
      accessToken: accessToken,
    );

    if (!mounted) return;
    _showSnack('Matière retirée.');
    setState(() => _future = _load());
  }

  Future<void> _deleteTeacher(ClassTeacher teacher) async {
    final shouldDelete = await _confirmResourceDelete(
      title: 'Retirer ce professeur ?',
      message:
          '“${teacher.displayName}” ne sera plus proposé dans les nouveaux cours.',
    );
    if (shouldDelete != true || !mounted) return;

    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    await appScope.classResourceRepository.deleteTeacher(
      teacherId: teacher.id,
      accessToken: accessToken,
    );

    if (!mounted) return;
    _showSnack('Professeur retiré.');
    setState(() => _future = _load());
  }

  Future<bool?> _confirmResourceDelete({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
  }
}

class _CreateClassForCurrentUserSheet extends StatefulWidget {
  const _CreateClassForCurrentUserSheet();

  @override
  State<_CreateClassForCurrentUserSheet> createState() =>
      _CreateClassForCurrentUserSheetState();
}

class _CreateClassForCurrentUserSheetState
    extends State<_CreateClassForCurrentUserSheet> {
  final _formKey = GlobalKey<FormState>();
  final _classNameController = TextEditingController(text: 'BTS SIO 1');
  final _schoolYearController = TextEditingController(text: '2026-2027');
  bool _isSaving = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 18,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                ProtoIconBox(icon: Icons.add_home_work_outlined),
                SizedBox(width: 12),
                Expanded(
                  child: ProtoSectionHeading(
                    overline: 'Classe',
                    title: 'Créer ma classe',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const ProtoMutedText(
              'À utiliser si tu as créé ton compte sans classe. Tu deviendras automatiquement délégué et un code sera généré.',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _classNameController,
              decoration: const InputDecoration(
                labelText: 'Nom de la classe',
                prefixIcon: Icon(Icons.groups_outlined),
              ),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _schoolYearController,
              decoration: const InputDecoration(
                labelText: 'Année scolaire',
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
              validator: _required,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _isSaving ? null : _submit,
                    child: Text(_isSaving ? 'Création...' : 'Créer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) {
    return (value ?? '').trim().isEmpty ? 'Champ obligatoire.' : null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      final session = await appScope.classManagementRepository.createClass(
        schoolClassName: _classNameController.text,
        schoolYear: _schoolYearController.text,
        accessToken: accessToken,
      );
      await appScope.sessionController.replaceSession(session);
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _schoolYearController.dispose();
    super.dispose();
  }
}

class _JoinClassSheet extends StatefulWidget {
  const _JoinClassSheet();

  @override
  State<_JoinClassSheet> createState() => _JoinClassSheetState();
}

class _JoinClassSheetState extends State<_JoinClassSheet> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 18,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                ProtoIconBox(icon: Icons.key_outlined),
                SizedBox(width: 12),
                Expanded(
                  child: ProtoSectionHeading(
                    overline: 'Classe',
                    title: 'Rejoindre avec un code',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const ProtoMutedText(
              'La demande reste en attente : tu ne vois aucune donnée scolaire tant qu’un délégué ne t’a pas approuvé.',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: const [_UpperCaseTextFormatter()],
              decoration: const InputDecoration(
                labelText: 'Code de classe',
                prefixIcon: Icon(Icons.password_outlined),
              ),
              validator: (value) {
                return (value ?? '').trim().isEmpty
                    ? 'Entre le code de classe.'
                    : null;
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _isSaving ? null : _submit,
                    child: Text(_isSaving ? 'Envoi...' : 'Envoyer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      await appScope.classManagementRepository.requestToJoinClass(
        code: _codeController.text,
        accessToken: accessToken,
      );
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  const _UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class _ClassEditSheet extends StatefulWidget {
  const _ClassEditSheet({required this.currentClass});

  final CurrentClassInfo currentClass;

  @override
  State<_ClassEditSheet> createState() => _ClassEditSheetState();
}

class _ClassEditSheetState extends State<_ClassEditSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _schoolYearController = TextEditingController();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.currentClass.name;
    _schoolYearController.text = widget.currentClass.schoolYear;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 18,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                ProtoIconBox(icon: Icons.school_outlined),
                SizedBox(width: 12),
                Expanded(
                  child: ProtoSectionHeading(
                    overline: 'Délégué',
                    title: 'Modifier la classe',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom de la classe',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _schoolYearController,
              decoration: const InputDecoration(
                labelText: 'Année scolaire',
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
              validator: _required,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _isSaving ? null : _submit,
                    child: Text(
                      _isSaving ? 'Enregistrement...' : 'Enregistrer',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) {
    return (value ?? '').trim().isEmpty ? 'Champ obligatoire.' : null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      await appScope.classManagementRepository.updateCurrentClass(
        name: _nameController.text,
        schoolYear: _schoolYearController.text,
        accessToken: accessToken,
      );
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _schoolYearController.dispose();
    super.dispose();
  }
}

class _ClassResourcesCard extends StatelessWidget {
  const _ClassResourcesCard({
    required this.subjects,
    required this.teachers,
    required this.isDelegate,
    required this.onAddSubject,
    required this.onAddTeacher,
    required this.onDeleteSubject,
    required this.onDeleteTeacher,
  });

  final List<ClassSubject> subjects;
  final List<ClassTeacher> teachers;
  final bool isDelegate;
  final VoidCallback onAddSubject;
  final VoidCallback onAddTeacher;
  final ValueChanged<ClassSubject> onDeleteSubject;
  final ValueChanged<ClassTeacher> onDeleteTeacher;

  @override
  Widget build(BuildContext context) {
    return ProtoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProtoSectionHeading(
            overline: 'Ressources',
            title: 'Matières et professeurs',
            trailing: isDelegate
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ProtoActionButton(
                        keyValue: 'add-subject-button',
                        icon: Icons.menu_book_outlined,
                        tooltip: 'Ajouter une matière',
                        onPressed: onAddSubject,
                      ),
                      const SizedBox(width: 6),
                      ProtoActionButton(
                        keyValue: 'add-teacher-button',
                        icon: Icons.person_add_alt_outlined,
                        tooltip: 'Ajouter un professeur',
                        onPressed: onAddTeacher,
                      ),
                    ],
                  )
                : null,
          ),
          const SizedBox(height: 8),
          const ProtoMutedText(
            'Ces listes servent à garder des cours cohérents. Les noms de professeurs sont protégés côté serveur.',
          ),
          const SizedBox(height: 12),
          _ResourceWrap(
            title: 'Matières',
            emptyText: 'Aucune matière enregistrée.',
            subjects: subjects,
            isDelegate: isDelegate,
            onDeleteSubject: onDeleteSubject,
          ),
          const SizedBox(height: 12),
          _TeacherList(
            teachers: teachers,
            isDelegate: isDelegate,
            onDeleteTeacher: onDeleteTeacher,
          ),
        ],
      ),
    );
  }
}

class _ClassMembersCard extends StatelessWidget {
  const _ClassMembersCard({
    required this.members,
    required this.isDelegate,
    required this.onMakeDelegate,
    required this.onRemoveMember,
    required this.onLeaveDelegateRole,
  });

  final List<ClassMember> members;
  final bool isDelegate;
  final ValueChanged<ClassMember> onMakeDelegate;
  final ValueChanged<ClassMember> onRemoveMember;
  final VoidCallback onLeaveDelegateRole;

  @override
  Widget build(BuildContext context) {
    return ProtoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProtoSectionHeading(
            overline: isDelegate ? 'Délégué' : 'Classe',
            title: 'Membres de la classe',
            trailing: isDelegate
                ? TextButton.icon(
                    onPressed: onLeaveDelegateRole,
                    icon: const Icon(Icons.remove_moderator_outlined, size: 16),
                    label: const Text('Quitter'),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          ProtoMutedText(
            isDelegate
                ? 'Tu peux retirer un élève ou nommer un autre délégué. Tu ne retires jamais le rôle délégué d’un autre élève.'
                : 'Liste des élèves approuvés dans ta classe.',
          ),
          const SizedBox(height: 10),
          if (members.isEmpty)
            const ProtoStateCard(
              icon: Icons.groups_outlined,
              title: 'Aucun membre affiché',
              message: 'Les membres apparaîtront ici après approbation.',
              compact: true,
            )
          else
            ...members.map(
              (member) => _ClassMemberRow(
                member: member,
                isDelegateMode: isDelegate,
                onMakeDelegate: () => onMakeDelegate(member),
                onRemoveMember: () => onRemoveMember(member),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClassMemberRow extends StatelessWidget {
  const _ClassMemberRow({
    required this.member,
    required this.isDelegateMode,
    required this.onMakeDelegate,
    required this.onRemoveMember,
  });

  final ClassMember member;
  final bool isDelegateMode;
  final VoidCallback onMakeDelegate;
  final VoidCallback onRemoveMember;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 11),
      margin: const EdgeInsets.only(top: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProtoIconBox(
            icon: member.isDelegate
                ? Icons.verified_user_outlined
                : Icons.person_outline,
            backgroundColor: member.isDelegate
                ? AppColors.mint
                : AppColors.primarySoft,
            size: 34,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.displayName,
                        style: TextStyle(
                          color: context.sfText,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (member.isDelegate) const ProtoChip(label: 'Délégué'),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  member.email,
                  style: TextStyle(color: context.sfMuted, fontSize: 8),
                ),
                if (isDelegateMode) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!member.isDelegate)
                        OutlinedButton.icon(
                          onPressed: onMakeDelegate,
                          icon: const Icon(
                            Icons.add_moderator_outlined,
                            size: 16,
                          ),
                          label: const Text('Nommer délégué'),
                        ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8D5C66),
                          side: const BorderSide(color: Color(0xFFD9BDC3)),
                        ),
                        onPressed: onRemoveMember,
                        icon: const Icon(
                          Icons.person_remove_outlined,
                          size: 16,
                        ),
                        label: const Text('Retirer'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceWrap extends StatelessWidget {
  const _ResourceWrap({
    required this.title,
    required this.emptyText,
    required this.subjects,
    required this.isDelegate,
    required this.onDeleteSubject,
  });

  final String title;
  final String emptyText;
  final List<ClassSubject> subjects;
  final bool isDelegate;
  final ValueChanged<ClassSubject> onDeleteSubject;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: context.sfText,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        if (subjects.isEmpty)
          ProtoMutedText(emptyText)
        else
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: subjects
                .map(
                  (subject) => InputChip(
                    label: Text(subject.name),
                    labelStyle: TextStyle(
                      color: context.sfText,
                      fontWeight: FontWeight.w800,
                    ),
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.14)
                        : AppColors.primarySoft,
                    deleteIconColor: context.sfChevron,
                    side: BorderSide(color: context.sfLine),
                    onDeleted: isDelegate
                        ? () => onDeleteSubject(subject)
                        : null,
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _TeacherList extends StatelessWidget {
  const _TeacherList({
    required this.teachers,
    required this.isDelegate,
    required this.onDeleteTeacher,
  });

  final List<ClassTeacher> teachers;
  final bool isDelegate;
  final ValueChanged<ClassTeacher> onDeleteTeacher;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Professeurs',
          style: TextStyle(
            color: context.sfText,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        if (teachers.isEmpty)
          const ProtoMutedText('Aucun professeur enregistré.')
        else
          ...teachers.map(
            (teacher) => Container(
              padding: const EdgeInsets.only(top: 9),
              margin: const EdgeInsets.only(top: 7),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: context.sfLine)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ProtoIconBox(
                    icon: Icons.badge_outlined,
                    backgroundColor: AppColors.mint,
                    size: 30,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          teacher.displayName,
                          style: TextStyle(
                            color: context.sfText,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (teacher.information case final information?) ...[
                          const SizedBox(height: 2),
                          ProtoMutedText(information),
                        ],
                      ],
                    ),
                  ),
                  if (isDelegate)
                    IconButton(
                      tooltip: 'Retirer le professeur',
                      onPressed: () => onDeleteTeacher(teacher),
                      icon: const Icon(Icons.close),
                      color: context.sfChevron,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CreateSubjectSheet extends StatefulWidget {
  const _CreateSubjectSheet();

  @override
  State<_CreateSubjectSheet> createState() => _CreateSubjectSheetState();
}

class _CreateSubjectSheetState extends State<_CreateSubjectSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return _ResourceFormScaffold(
      title: 'Ajouter une matière',
      icon: Icons.menu_book_outlined,
      isSaving: _isSaving,
      errorMessage: _errorMessage,
      onSubmit: _submit,
      child: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nom de la matière',
            prefixIcon: Icon(Icons.school_outlined),
          ),
          validator: (value) {
            return (value ?? '').trim().isEmpty
                ? 'Entre le nom de la matière.'
                : null;
          },
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      await appScope.classResourceRepository.createSubject(
        name: _nameController.text,
        accessToken: accessToken,
      );
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}

class _CreateTeacherSheet extends StatefulWidget {
  const _CreateTeacherSheet();

  @override
  State<_CreateTeacherSheet> createState() => _CreateTeacherSheetState();
}

class _CreateTeacherSheetState extends State<_CreateTeacherSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _informationController = TextEditingController();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return _ResourceFormScaffold(
      title: 'Ajouter un professeur',
      icon: Icons.person_add_alt_outlined,
      isSaving: _isSaving,
      errorMessage: _errorMessage,
      onSubmit: _submit,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nom affiché',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (value) {
                return (value ?? '').trim().isEmpty
                    ? 'Entre le nom du professeur.'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _informationController,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Information utile (optionnel)',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      await appScope.classResourceRepository.createTeacher(
        displayName: _nameController.text,
        information: _informationController.text,
        accessToken: accessToken,
      );
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _informationController.dispose();
    super.dispose();
  }
}

class _ResourceFormScaffold extends StatelessWidget {
  const _ResourceFormScaffold({
    required this.title,
    required this.icon,
    required this.isSaving,
    required this.onSubmit,
    required this.child,
    this.errorMessage,
  });

  final String title;
  final IconData icon;
  final bool isSaving;
  final VoidCallback onSubmit;
  final Widget child;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 18,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProtoIconBox(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: ProtoSectionHeading(overline: 'Classe', title: title),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
          if (errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: isSaving ? null : onSubmit,
                  child: Text(isSaving ? 'Ajout...' : 'Ajouter'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingRequestRow extends StatelessWidget {
  const _PendingRequestRow({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  final PendingMembershipRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 11),
      margin: const EdgeInsets.only(top: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProtoIconBox(icon: Icons.person_add_alt_1_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  request.displayName,
                  style: TextStyle(
                    color: context.sfText,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  request.email,
                  style: TextStyle(color: context.sfMuted, fontSize: 8),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilledButton(
                      onPressed: onApprove,
                      child: const Text('Approuver'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: onReject,
                      child: const Text('Refuser'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassManagementState {
  const _ClassManagementState({
    required this.currentClass,
    required this.pendingRequests,
    required this.members,
    required this.subjects,
    required this.teachers,
  });

  final CurrentClassInfo? currentClass;
  final List<PendingMembershipRequest> pendingRequests;
  final List<ClassMember> members;
  final List<ClassSubject> subjects;
  final List<ClassTeacher> teachers;
}

class _SettingsGroupTitle extends StatelessWidget {
  const _SettingsGroupTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : AppColors.petrol,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.petrol : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.14) : AppColors.line,
        ),
      ),
      child: Column(children: children),
    );
  }
}

class _SwitchSettingLine extends StatelessWidget {
  const _SwitchSettingLine({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.switchKey,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Key? switchKey;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.14)
                    : AppColors.line,
              ),
            ),
          ),
          child: Row(
            children: [
              ProtoIconBox(icon: icon, backgroundColor: iconColor, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.petrol,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : AppColors.muted,
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                key: switchKey,
                value: value,
                onChanged: onChanged,
                activeThumbColor: isDark ? AppColors.petrolDark : Colors.white,
                activeTrackColor: isDark ? AppColors.mint : AppColors.petrol,
                inactiveThumbColor: isDark
                    ? Colors.white.withValues(alpha: 0.70)
                    : Colors.white,
                inactiveTrackColor: isDark
                    ? Colors.white.withValues(alpha: 0.18)
                    : AppColors.line,
                trackOutlineColor: WidgetStateProperty.resolveWith(
                  (states) => isDark
                      ? Colors.white.withValues(alpha: 0.18)
                      : AppColors.line,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
