import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/settings/app_settings_controller.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/features/announcements/domain/class_announcement_models.dart';
import 'package:studyflow_app/core/widgets/date_time_pickers.dart';
import 'package:studyflow_app/features/dashboard/domain/dashboard_models.dart';
import 'package:studyflow_app/features/exams/domain/exam_models.dart';
import 'package:studyflow_app/features/exams/presentation/exam_widgets.dart';
import 'package:studyflow_app/features/exams/presentation/exams_page.dart';
import 'package:studyflow_app/features/groups/presentation/groups_dashboard_section.dart';
import 'package:studyflow_app/features/notes/application/daily_notes_controller.dart';
import 'package:studyflow_app/features/notes/presentation/daily_note_page.dart';
import 'package:studyflow_app/features/notes/presentation/quick_note_sheet.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    required this.onOpenSchedule,
    required this.onOpenAgenda,
    super.key,
  });

  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenAgenda;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Future<DashboardSummary>? _dashboardFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dashboardFuture ??= _loadDashboard();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardSummary>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ProtoPageLoader(label: 'Tableau de bord');
        }

        if (snapshot.hasError) {
          return _DashboardError(onRetry: _refresh);
        }

        return _DashboardContent(
          dashboard: snapshot.requireData,
          onRefresh: _refresh,
          onOpenSchedule: widget.onOpenSchedule,
          onOpenAgenda: widget.onOpenAgenda,
        );
      },
    );
  }

  Future<DashboardSummary> _loadDashboard() async {
    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();

    return appScope.dashboardRepository.getDashboard(accessToken: accessToken);
  }

  Future<void> _refresh() async {
    setState(() {
      _dashboardFuture = _loadDashboard();
    });
    await _dashboardFuture!;
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.dashboard,
    required this.onRefresh,
    required this.onOpenSchedule,
    required this.onOpenAgenda,
  });

  final DashboardSummary dashboard;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenAgenda;

  @override
  Widget build(BuildContext context) {
    final appScope = AppScope.of(context);
    final user = appScope.sessionController.session?.user;
    final firstName = (user?.firstName.trim().isNotEmpty ?? false)
        ? user!.firstName.trim()
        : 'toi';
    final initials = _initials(user?.firstName, user?.lastName);
    final notes = appScope.dailyNotesController;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 26, 18, 112),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (dashboard.classLabel case final label?) ...[
                        _ClassPill(text: label),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        'Bonjour $firstName',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.2,
                            ),
                      ),
                      Text(
                        dashboard.hasClass
                            ? 'Voici l’essentiel de ta journée.'
                            : 'Organise ta recherche d’alternance et rejoins ta classe plus tard.',
                        style: TextStyle(color: context.sfMuted),
                      ),
                    ],
                  ),
                ),
                _DailyNoteButton(
                  controller: notes,
                  settings: appScope.settingsController,
                ),
                _AvatarBadge(initials: initials),
              ],
            ),
            const SizedBox(height: 20),
            _EveningNoteCard(
              controller: notes,
              settings: appScope.settingsController,
            ),
            // Prochain cours et infos classe côte à côte : les devoirs à
            // rendre restent visibles sans faire défiler.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _NextCourseCard(
                      course: dashboard.nextCourse,
                      onTap: onOpenSchedule,
                    ),
                  ),
                  if (dashboard.hasClass) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ClassInfoTile(
                        pinned: dashboard.pinnedAnnouncements,
                        refreshedAt: dashboard.generatedAt,
                        onOpenFeed: () => _openAnnouncementFeed(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (dashboard.hasClass) ...[
              _SectionHeader(
                overline: 'À rendre bientôt',
                title: 'Devoirs et projets',
                color: AppColors.petrol,
              ),
              _UpcomingHomeworkCard(
                homework: dashboard.upcomingHomework,
                onOpenAgenda: onOpenAgenda,
              ),
              _ExamsDashboardCard(refreshedAt: dashboard.generatedAt),
              GroupsDashboardSection(refreshedAt: dashboard.generatedAt),
            ],
            _SectionHeader(
              overline: 'Mon organisation',
              title: 'Mes tâches',
              color: AppColors.green,
            ),
            _SummaryTile(
              icon: Icons.checklist_outlined,
              title: '${dashboard.personalTasks.length} tâches personnelles',
              subtitle: dashboard.personalTasks.isEmpty
                  ? 'Ta liste personnelle est vide'
                  : dashboard.personalTasks.first.title,
              onTap: onOpenAgenda,
            ),
            _SummaryTile(
              icon: Icons.event_available_outlined,
              title: '${dashboard.todayEvents.length} événements aujourd’hui',
              subtitle: dashboard.todayEvents.isEmpty
                  ? 'Aucun événement prévu'
                  : dashboard.todayEvents.first.title,
              onTap: onOpenAgenda,
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String? firstName, String? lastName) {
    final first = (firstName ?? '').trim();
    final last = (lastName ?? '').trim();
    final letters = [
      if (first.isNotEmpty) first.characters.first,
      if (last.isNotEmpty) last.characters.first,
    ].join().toUpperCase();

    return letters.isEmpty ? 'S' : letters;
  }

  Future<void> _openAnnouncementFeed(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const _AnnouncementFeedSheet(),
    );
  }
}

class _ClassPill extends StatelessWidget {
  const _ClassPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.14)
            : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: context.sfText,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: .6,
        ),
      ),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF17657A), AppColors.petrol],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33073B4C),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// Coin note (facultatif) : un appui ouvre la saisie rapide, un appui long la
/// note complète. Un point indique qu'il y a déjà quelque chose ; le soir, tant
/// que la note n'a pas été relue, le bouton passe en surbrillance et l'appui
/// ouvre directement la note pour la relire.
class _DailyNoteButton extends StatelessWidget {
  const _DailyNoteButton({required this.controller, required this.settings});

  final DailyNotesController controller;
  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, settings]),
      builder: (context, _) {
        if (!settings.dailyNotesEnabled) return const SizedBox.shrink();

        final now = DateTime.now();
        final hasNote = controller.noteFor(now)?.isEmpty == false;
        final highlight =
            settings.dailyNoteReminderEnabled && controller.needsReview(now);

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Tooltip(
            message: 'Note rapide (appui long : note du jour)',
            child: Material(
              color: highlight ? context.sfEvaluation : context.sfCard,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                key: const ValueKey('daily-note-button'),
                borderRadius: BorderRadius.circular(16),
                onTap: highlight
                    ? () => DailyNotePage.open(context)
                    : () => QuickNoteSheet.show(context),
                onLongPress: () => DailyNotePage.open(context),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: highlight ? Colors.transparent : context.sfLine,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.edit_note,
                        color: highlight ? Colors.white : context.sfIcon,
                      ),
                      if (hasNote && !highlight)
                        Positioned(
                          top: 9,
                          right: 9,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: context.sfEvaluation,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Le soir, rappelle ce qui a été noté dans la journée.
class _EveningNoteCard extends StatelessWidget {
  const _EveningNoteCard({required this.controller, required this.settings});

  final DailyNotesController controller;
  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, settings]),
      builder: (context, _) {
        final now = DateTime.now();
        final note = controller.noteFor(now);
        if (note == null ||
            !settings.dailyNoteReminderEnabled ||
            !controller.needsReview(now)) {
          return const SizedBox.shrink();
        }

        return ProtoCard(
          key: const ValueKey('evening-note-card'),
          onTap: () => DailyNotePage.open(context),
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          borderColor: context.sfEvaluation,
          backgroundColor: context.sfEvaluationSoft,
          child: Row(
            children: [
              ProtoIconBox(
                icon: Icons.edit_note,
                backgroundColor: context.sfCard,
                foregroundColor: context.sfEvaluation,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Overline(
                      text: 'Fin de journée',
                      color: context.sfEvaluation,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      note.preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.sfText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const ProtoMutedText('Relis ta note du jour avant demain.'),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.sfEvaluation),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.overline,
    required this.title,
    required this.color,
  });

  final String overline;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Overline(text: overline, color: color),
          const SizedBox(height: 3),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _Overline extends StatelessWidget {
  const _Overline({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = isDark && color == AppColors.petrol
        ? Colors.white70
        : color;

    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: effectiveColor,
        fontSize: 13,
        fontWeight: FontWeight.w900,
        letterSpacing: .8,
      ),
    );
  }
}

/// Demi-carte : prochain cours de la classe.
class _NextCourseCard extends StatelessWidget {
  const _NextCourseCard({required this.course, required this.onTap});

  final CourseSummary? course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final course = this.course;
    const muted = Color(0xCFFFFFFF);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: const RadialGradient(
            center: Alignment(.95, -.75),
            radius: 1.4,
            colors: [Color(0x9984DCCF), AppColors.petrol],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40073B4C),
              blurRadius: 26,
              offset: Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              course == null ? 'AUCUN COURS' : 'PROCHAIN COURS',
              style: const TextStyle(
                color: Color(0xBFFFFFFF),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              course?.subjectName ?? 'Rien de prévu pour l’instant.',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                height: 1.2,
                fontWeight: FontWeight.w900,
                letterSpacing: -.4,
              ),
            ),
            const Spacer(),
            if (course != null) ...[
              const SizedBox(height: 10),
              Text(
                '${_dayLabel(course.day)} ${course.startsAt}–${course.endsAt}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Salle ${course.room}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _dayLabel(DateTime day) {
    final today = DateUtils.dateOnly(DateTime.now());
    final difference = DateUtils.dateOnly(day).difference(today).inDays;
    return switch (difference) {
      0 => 'Auj.',
      1 => 'Demain',
      _ => StudyFlowFormat.shortDay(day),
    };
  }
}

/// Demi-carte : fil officiel de la classe, l'annonce épinglée en premier.
class _ClassInfoTile extends StatefulWidget {
  const _ClassInfoTile({
    required this.pinned,
    required this.refreshedAt,
    required this.onOpenFeed,
  });

  final List<ClassAnnouncementSummary> pinned;
  final DateTime refreshedAt;
  final VoidCallback onOpenFeed;

  @override
  State<_ClassInfoTile> createState() => _ClassInfoTileState();
}

class _ClassInfoTileState extends State<_ClassInfoTile> {
  Future<List<ClassAnnouncement>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  @override
  void didUpdateWidget(covariant _ClassInfoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshedAt != widget.refreshedAt) _future = _load();
  }

  Future<List<ClassAnnouncement>> _load() async {
    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      return await appScope.classAnnouncementRepository.listAnnouncements(
        accessToken: accessToken,
      );
    } on Exception {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ClassAnnouncement>>(
      future: _future,
      builder: (context, snapshot) {
        final announcements = snapshot.data ?? const <ClassAnnouncement>[];
        final pinned = widget.pinned.firstOrNull;
        final latest = announcements.firstOrNull;
        final content = pinned?.content ?? latest?.content;
        final isPinned = pinned != null || latest?.isPinned == true;

        return ProtoCard(
          key: const ValueKey('class-info-tile'),
          onTap: widget.onOpenFeed,
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(14),
          borderRadius: 22,
          borderColor: const Color(0xFFA6D9F7),
          backgroundColor: const Color(0xFFEDF8FD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    size: 18,
                    color: context.sfShared,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _Overline(
                      text: 'Infos classe',
                      color: context.sfShared,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (isPinned)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.push_pin,
                        size: 13,
                        color: AppColors.rose,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Épinglé',
                        style: TextStyle(
                          color: context.sfMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                content ??
                    (snapshot.connectionState == ConnectionState.done
                        ? 'Aucune info officielle pour le moment.'
                        : '…'),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.sfText,
                  fontSize: 14,
                  height: 1.3,
                  fontWeight: content == null
                      ? FontWeight.w500
                      : FontWeight.w800,
                ),
              ),
              const Spacer(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      announcements.isEmpty
                          ? 'Fil officiel'
                          : 'Fil officiel · ${announcements.length}',
                      style: TextStyle(
                        color: context.sfShared,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: context.sfShared),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Les prochains rendus, visibles d'un coup d'œil (évaluations en ambre).
class _UpcomingHomeworkCard extends StatelessWidget {
  const _UpcomingHomeworkCard({
    required this.homework,
    required this.onOpenAgenda,
  });

  static const _visible = 3;

  final List<HomeworkSummary> homework;
  final VoidCallback onOpenAgenda;

  @override
  Widget build(BuildContext context) {
    if (homework.isEmpty) {
      return _SummaryTile(
        icon: Icons.assignment_outlined,
        title: 'Aucun devoir à venir',
        subtitle: 'Rien d’urgent pour le moment',
        onTap: onOpenAgenda,
      );
    }

    return ProtoCard(
      key: const ValueKey('upcoming-homework-card'),
      onTap: onOpenAgenda,
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      child: Column(
        children: [
          for (final item in homework.take(_visible))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  _DueBadge(deadline: item.deadline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (item.isEvaluation) ...[
                              Icon(
                                Icons.grading_outlined,
                                size: 15,
                                color: context.sfEvaluation,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Flexible(
                              child: Text(
                                item.subjectName ??
                                    (item.isEvaluation
                                        ? 'Évaluation'
                                        : 'Devoir'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: item.isEvaluation
                                      ? context.sfEvaluation
                                      : context.sfShared,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.sfText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: ProtoMutedText(
                  homework.length > _visible
                      ? '+ ${homework.length - _visible} autre${homework.length - _visible > 1 ? 's' : ''} dans l’agenda'
                      : 'Tout est dans l’agenda',
                ),
              ),
              Icon(Icons.chevron_right, color: context.sfChevron),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// « Demain », « 3 j », « Auj. » : le délai avant le rendu.
class _DueBadge extends StatelessWidget {
  const _DueBadge({required this.deadline});

  final DateTime deadline;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final days = DateUtils.dateOnly(deadline).difference(today).inDays;
    final urgent = days <= 1;
    final label = switch (days) {
      < 0 => 'Retard',
      0 => 'Auj.',
      1 => 'Demain',
      _ => '$days j',
    };
    final color = urgent ? AppColors.danger : context.sfShared;

    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: urgent
            ? AppColors.danger.withValues(alpha: 0.10)
            : context.sfSharedSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AnnouncementMiniCard extends StatelessWidget {
  const _AnnouncementMiniCard(
    this.announcement, {
    this.canManage = false,
    this.onDelete,
    this.onTogglePin,
  });

  final ClassAnnouncement announcement;
  final bool canManage;
  final VoidCallback? onDelete;
  final VoidCallback? onTogglePin;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: context.sfCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: announcement.isPinned ? AppColors.rose : context.sfLine,
          width: announcement.isPinned ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            announcement.isPinned
                ? Icons.push_pin_outlined
                : Icons.info_outline,
            color: announcement.isPinned
                ? AppColors.rose
                : isDark
                ? Colors.white
                : AppColors.petrol,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  announcement.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.sfText,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${announcement.authorName} · ${_formatDate(announcement.updatedAt)}',
                  style: TextStyle(color: context.sfMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (canManage)
            PopupMenuButton<_AnnouncementAction>(
              tooltip: 'Actions annonce',
              icon: const Icon(Icons.more_horiz, size: 18),
              onSelected: (action) {
                switch (action) {
                  case _AnnouncementAction.togglePin:
                    onTogglePin?.call();
                  case _AnnouncementAction.delete:
                    onDelete?.call();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _AnnouncementAction.togglePin,
                  child: Text(
                    announcement.isPinned ? 'Désépingler' : 'Épingler',
                  ),
                ),
                const PopupMenuItem(
                  value: _AnnouncementAction.delete,
                  child: Text('Supprimer'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }
}

enum _AnnouncementAction { togglePin, delete }

class _CreateAnnouncementSheet extends StatefulWidget {
  const _CreateAnnouncementSheet();

  @override
  State<_CreateAnnouncementSheet> createState() =>
      _CreateAnnouncementSheetState();
}

class _CreateAnnouncementSheetState extends State<_CreateAnnouncementSheet> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  bool _isPinned = true;
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
            const ProtoSectionHeading(
              overline: 'Délégué',
              title: 'Publier une info',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _contentController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Message important',
                prefixIcon: Icon(Icons.campaign_outlined),
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Écris un message.' : null,
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isPinned,
              onChanged: (value) => setState(() => _isPinned = value),
              title: const Text('Épingler cette info'),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
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
                    child: Text(_isSaving ? 'Publication...' : 'Publier'),
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
      await appScope.classAnnouncementRepository.createAnnouncement(
        content: _contentController.text,
        isPinned: _isPinned,
        accessToken: accessToken,
      );
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ProtoCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 51,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: context.sfIcon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.sfMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right, color: context.sfChevron),
        ],
      ),
    );
  }
}

class _AnnouncementFeedSheet extends StatelessWidget {
  const _AnnouncementFeedSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      maxChildSize: 0.94,
      minChildSize: 0.45,
      builder: (context, scrollController) {
        return _ClassFeedFullList(scrollController: scrollController);
      },
    );
  }
}

class _ClassFeedFullList extends StatefulWidget {
  const _ClassFeedFullList({required this.scrollController});

  final ScrollController scrollController;

  @override
  State<_ClassFeedFullList> createState() => _ClassFeedFullListState();
}

class _ClassFeedFullListState extends State<_ClassFeedFullList> {
  Future<List<ClassAnnouncement>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).sessionController.session?.user;
    final canManage = user?.isDelegate == true;

    return FutureBuilder<List<ClassAnnouncement>>(
      future: _future,
      builder: (context, snapshot) {
        final announcements = snapshot.data ?? const <ClassAnnouncement>[];
        return ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            Row(
              children: [
                const Expanded(
                  child: ProtoSectionHeading(
                    overline: 'Infos classe',
                    title: 'Fil officiel de la classe',
                  ),
                ),
                if (canManage)
                  FilledButton.tonalIcon(
                    key: const ValueKey('publish-announcement-button'),
                    onPressed: _openCreateSheet,
                    icon: const Icon(Icons.add),
                    label: const Text('Publier'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (snapshot.connectionState != ConnectionState.done)
              const LinearProgressIndicator(minHeight: 3)
            else if (announcements.isEmpty)
              const ProtoStateCard(
                icon: Icons.campaign_outlined,
                title: 'Aucune info officielle',
                message: 'Les annonces importantes apparaîtront ici.',
                compact: true,
              )
            else
              ...announcements.map(
                (announcement) => _AnnouncementMiniCard(
                  announcement,
                  canManage: canManage,
                  onDelete: () => _deleteAnnouncement(announcement),
                  onTogglePin: () => _togglePin(announcement),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<List<ClassAnnouncement>> _load() async {
    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    return appScope.classAnnouncementRepository.listAnnouncements(
      accessToken: accessToken,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const _CreateAnnouncementSheet(),
    );

    if (created == true && mounted) await _refresh();
  }

  Future<void> _deleteAnnouncement(ClassAnnouncement announcement) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette annonce ?'),
        content: Text('“${announcement.content}” sera retirée du fil.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    await appScope.classAnnouncementRepository.deleteAnnouncement(
      announcementId: announcement.id,
      accessToken: accessToken,
    );

    if (mounted) await _refresh();
  }

  Future<void> _togglePin(ClassAnnouncement announcement) async {
    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    await appScope.classAnnouncementRepository.updateAnnouncement(
      announcement: announcement,
      isPinned: !announcement.isPinned,
      accessToken: accessToken,
    );

    if (mounted) await _refresh();
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ProtoStateCard(
      icon: Icons.cloud_off_outlined,
      title: 'Tableau de bord indisponible',
      message: 'Vérifie le réseau ou relance le backend, puis réessaie.',
      actionLabel: 'Réessayer',
      onAction: onRetry,
    );
  }
}

/// Partiels : la carte apparaît d'elle-même deux semaines avant. Un délégué
/// voit aussi les partiels qu'il prépare, encore cachés à la classe.
class _ExamsDashboardCard extends StatefulWidget {
  const _ExamsDashboardCard({required this.refreshedAt});

  final DateTime refreshedAt;

  @override
  State<_ExamsDashboardCard> createState() => _ExamsDashboardCardState();
}

class _ExamsDashboardCardState extends State<_ExamsDashboardCard> {
  Future<List<ExamSession>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  @override
  void didUpdateWidget(covariant _ExamsDashboardCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshedAt != widget.refreshedAt) _future = _load();
  }

  Future<List<ExamSession>> _load() async {
    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      return await appScope.examRepository.listSessions(
        accessToken: accessToken,
      );
    } on Exception {
      // Carte facultative : sans réseau, l'accueil reste utilisable.
      return const [];
    }
  }

  Future<void> _open(ExamSession session) async {
    await ExamsPage.open(context, sessionId: session.id);
    if (mounted) {
      setState(() {
        _future = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ExamSession>>(
      future: _future,
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? const <ExamSession>[];
        final open = sessions.where((x) => x.isOpen).firstOrNull;
        if (open != null) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: ExamCountdownHeader(
              session: open,
              compact: true,
              onTap: () => _open(open),
            ),
          );
        }

        final preparing = sessions.firstOrNull;
        if (preparing == null) return const SizedBox.shrink();
        return ProtoCard(
          onTap: () => _open(preparing),
          margin: const EdgeInsets.only(bottom: 18),
          child: Row(
            children: [
              ProtoIconBox(
                icon: Icons.school_outlined,
                backgroundColor: context.sfSharedSoft,
                foregroundColor: context.sfShared,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${preparing.title} en préparation',
                      style: TextStyle(
                        color: context.sfText,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    ProtoMutedText(
                      'Visible par la classe à partir du ${StudyFlowFormat.shortDay(preparing.opensOn)}',
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.sfChevron),
            ],
          ),
        );
      },
    );
  }
}
