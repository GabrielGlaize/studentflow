import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/features/announcements/domain/class_announcement_models.dart';
import 'package:studyflow_app/features/dashboard/domain/dashboard_models.dart';

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
    final user = AppScope.of(context).sessionController.session?.user;
    final firstName = (user?.firstName.trim().isNotEmpty ?? false)
        ? user!.firstName.trim()
        : 'toi';
    final initials = _initials(user?.firstName, user?.lastName);

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
                      const _ClassPill(text: 'L2 DEV · 2026–2027'),
                      const SizedBox(height: 12),
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
                _AvatarBadge(initials: initials),
              ],
            ),
            const SizedBox(height: 24),
            _PinnedAnnouncementCard(
              announcements: dashboard.pinnedAnnouncements,
              onTap: () => _openAnnouncementFeed(context),
            ),
            const SizedBox(height: 18),
            _NextCourseCard(
              course: dashboard.nextCourse,
              onTap: onOpenSchedule,
            ),
            const SizedBox(height: 18),
            _ClassFeedSection(
              onOpenFullFeed: () => _openAnnouncementFeed(context),
            ),
            const SizedBox(height: 18),
            _SectionHeader(
              overline: 'À rendre bientôt',
              title: 'Devoirs et projets',
              color: AppColors.petrol,
            ),
            _SummaryTile(
              icon: Icons.assignment_outlined,
              title: '${dashboard.upcomingHomework.length} devoirs à venir',
              subtitle: dashboard.upcomingHomework.isEmpty
                  ? 'Rien d’urgent pour le moment'
                  : dashboard.upcomingHomework.first.title,
              onTap: onOpenAgenda,
            ),
            const SizedBox(height: 8),
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
            _SummaryTile(
              icon: Icons.campaign_outlined,
              title:
                  '${dashboard.pinnedAnnouncements.length} annonces épinglées',
              subtitle: dashboard.pinnedAnnouncements.isEmpty
                  ? 'Aucune annonce importante'
                  : dashboard.pinnedAnnouncements.first.content,
              onTap: () => _openAnnouncementFeed(context),
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

    return letters.isEmpty ? 'SF' : letters;
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
          fontSize: 10,
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

class _PinnedAnnouncementCard extends StatelessWidget {
  const _PinnedAnnouncementCard({
    required this.announcements,
    required this.onTap,
  });

  final List<ClassAnnouncementSummary> announcements;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final announcement = announcements.isEmpty ? null : announcements.first;

    return ProtoCard(
      onTap: onTap,
      padding: const EdgeInsets.all(15),
      borderColor: AppColors.rose,
      backgroundColor: AppColors.roseSoft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x17073B4C),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.push_pin_outlined, color: AppColors.rose),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Overline(
                  text: 'Épinglé par le délégué',
                  color: AppColors.rose,
                ),
                const SizedBox(height: 4),
                Text(
                  announcement?.content ?? 'Aucune annonce épinglée',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  announcement == null
                      ? 'Le fil officiel reste accessible ici.'
                      : '${announcement.authorName} · toucher pour ouvrir le fil',
                  style: TextStyle(color: context.sfMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.rose),
        ],
      ),
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
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: .8,
      ),
    );
  }
}

class _NextCourseCard extends StatelessWidget {
  const _NextCourseCard({required this.course, required this.onTap});

  final CourseSummary? course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final course = this.course;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: const RadialGradient(
            center: Alignment(.95, -.75),
            radius: 1.25,
            colors: [Color(0x9984DCCF), AppColors.petrol],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40073B4C),
              blurRadius: 34,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course == null ? 'AUCUN COURS À VENIR' : 'TON PROCHAIN COURS',
                style: const TextStyle(
                  color: Color(0xBFFFFFFF),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                course?.subjectName ?? 'Respire, rien de prévu pour l’instant.',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.5,
                ),
              ),
              if (course != null) ...[
                const SizedBox(height: 12),
                Text(
                  '${course.startsAt}–${course.endsAt} · Salle ${course.room}'
                  '${course.teacherName == null ? '' : ' · ${course.teacherName}'}',
                  style: const TextStyle(color: Color(0xCFFFFFFF)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassFeedSection extends StatefulWidget {
  const _ClassFeedSection({required this.onOpenFullFeed});

  final VoidCallback onOpenFullFeed;

  @override
  State<_ClassFeedSection> createState() => _ClassFeedSectionState();
}

class _ClassFeedSectionState extends State<_ClassFeedSection> {
  Future<List<ClassAnnouncement>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).sessionController.session?.user;
    final canPublish = user?.isDelegate == true;

    return FutureBuilder<List<ClassAnnouncement>>(
      future: _future,
      builder: (context, snapshot) {
        final announcements = snapshot.data ?? const <ClassAnnouncement>[];

        return ProtoCard(
          borderRadius: 20,
          borderColor: const Color(0xFFA6D9F7),
          backgroundColor: const Color(0xFFEDF8FD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProtoIconBox(
                    icon: Icons.campaign_outlined,
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.14)
                        : Colors.white,
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: ProtoSectionHeading(
                      overline: 'Infos classe',
                      title: 'Fil officiel',
                    ),
                  ),
                  if (canPublish)
                    IconButton(
                      tooltip: 'Publier une info',
                      onPressed: _openCreateSheet,
                      icon: const Icon(Icons.add),
                      color: context.sfIcon,
                    ),
                  IconButton(
                    tooltip: 'Ouvrir le fil',
                    onPressed: widget.onOpenFullFeed,
                    icon: const Icon(Icons.chevron_right),
                    color: context.sfChevron,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (snapshot.connectionState != ConnectionState.done)
                const LinearProgressIndicator(minHeight: 3)
              else if (announcements.isEmpty)
                const ProtoMutedText(
                  'Aucune information officielle pour le moment.',
                )
              else
                ...announcements
                    .take(2)
                    .map(
                      (announcement) => _AnnouncementMiniCard(
                        announcement,
                        canManage: canPublish,
                        onDelete: () => _deleteAnnouncement(announcement),
                        onTogglePin: () => _togglePin(announcement),
                      ),
                    ),
            ],
          ),
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
    setState(() => _future = _load());
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
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${announcement.authorName} · ${_formatDate(announcement.updatedAt)}',
                  style: TextStyle(color: context.sfMuted, fontSize: 8),
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
            const ProtoSectionHeading(
              overline: 'Délégué',
              title: 'Fil officiel de la classe',
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
    setState(() => _future = _load());
    await _future;
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
