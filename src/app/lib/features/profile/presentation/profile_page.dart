import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/features/classes/domain/class_models.dart';
import 'package:studyflow_app/features/classes/presentation/class_resources_page.dart';
import 'package:studyflow_app/features/classes/domain/class_resource_models.dart';
import 'package:studyflow_app/features/company/application/company_documents_controller.dart';
import 'package:studyflow_app/features/notifications/application/reminder_planner.dart';
import 'package:studyflow_app/features/notifications/domain/notification_models.dart';
import 'package:studyflow_app/features/profile/domain/app_preferences.dart';
import 'package:studyflow_app/features/profile/domain/notification_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

part 'profile_preferences_section.dart';
part 'profile_student_card.dart';
part 'profile_class_management.dart';
part 'profile_class_sheets.dart';
part 'profile_class_resources.dart';

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
                onImport: () => _importStudentCard(context, studentCard),
                onOpen: studentCard == null
                    ? null
                    : () => _openStudentCard(context, studentCard!),
                onDelete: studentCardId == null
                    ? null
                    : () => _deleteStudentCard(context, studentCard!),
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
                style: TextStyle(color: context.sfMuted, fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _importStudentCard(
    BuildContext context,
    CompanyDocument? previous,
  ) async {
    final controller = AppScope.of(context).companyDocumentsController;
    final String? relativePath;
    try {
      relativePath = await StudentCardStore.importPhoto();
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(content: Text('Impossible d’importer cette photo.')),
          );
      }
      return;
    }
    if (relativePath == null) return;

    if (previous != null) {
      controller.deleteDocument(previous.id);
      await StudentCardStore.delete(previous.filePath);
    }
    controller.addDocument(
      title: 'Carte étudiante',
      kind: 'Carte étudiante',
      scope: 'student-card',
      fileName: relativePath.split('/').last,
      filePath: relativePath,
    );
  }

  Future<void> _deleteStudentCard(
    BuildContext context,
    CompanyDocument document,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Retirer la carte étudiante ?'),
        content: const Text('La photo sera supprimée de l’app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    AppScope.of(context).companyDocumentsController.deleteDocument(document.id);
    await StudentCardStore.delete(document.filePath);
  }

  Future<void> _openStudentCard(
    BuildContext context,
    CompanyDocument document,
  ) async {
    final hasPhoto = document.filePath?.trim().isNotEmpty == true;
    final link = document.link?.trim();

    // Anciennes cartes enregistrées sous forme de lien seulement.
    if (!hasPhoto && link != null && link.isNotEmpty) {
      final uri = Uri.tryParse(link);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => _StudentCardViewer(storedPath: document.filePath),
      ),
    );
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
                  style: TextStyle(color: context.sfMuted, fontSize: 12),
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
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : AppColors.muted,
                        fontSize: 11,
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
