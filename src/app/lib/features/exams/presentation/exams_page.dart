import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/core/widgets/date_time_pickers.dart';
import 'package:studyflow_app/features/exams/domain/exam_models.dart';
import 'package:studyflow_app/features/exams/presentation/exam_session_form_page.dart';
import 'package:studyflow_app/features/exams/presentation/exam_subject_page.dart';
import 'package:studyflow_app/features/exams/presentation/exam_widgets.dart';

/// Les partiels de la classe : compte à rebours, progression et une fiche de
/// révision collaborative par matière.
class ExamsPage extends StatefulWidget {
  const ExamsPage({this.initialSessionId, super.key});

  final String? initialSessionId;

  static Future<void> open(BuildContext context, {String? sessionId}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ExamsPage(initialSessionId: sessionId),
      ),
    );
  }

  @override
  State<ExamsPage> createState() => _ExamsPageState();
}

class _ExamsPageState extends State<ExamsPage> {
  Future<List<ExamSession>>? _future;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialSessionId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  bool get _isDelegate =>
      AppScope.of(context).sessionController.session?.user.isDelegate == true;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ExamSession>>(
      future: _future,
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? const <ExamSession>[];
        final session = _selected(sessions);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Partiels'),
            actions: [
              if (session != null && _isDelegate)
                PopupMenuButton<String>(
                  tooltip: 'Gérer les partiels',
                  onSelected: (value) => switch (value) {
                    'edit' => _editSession(session),
                    'new' => _createSession(),
                    _ => null,
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_calendar_outlined),
                        title: Text('Modifier les dates et matières'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'new',
                      child: ListTile(
                        leading: Icon(Icons.add),
                        title: Text('Préparer d’autres partiels'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          body: switch (snapshot.connectionState) {
            ConnectionState.done when snapshot.hasError => ProtoStateCard(
              icon: Icons.cloud_off_outlined,
              title: 'Partiels indisponibles',
              message: 'Impossible de charger les partiels de la classe.',
              actionLabel: 'Réessayer',
              onAction: _refresh,
            ),
            ConnectionState.done when session == null => _EmptyExams(
              isDelegate: _isDelegate,
              onCreate: _createSession,
            ),
            ConnectionState.done => RefreshIndicator(
              onRefresh: _refresh,
              child: _SessionView(
                session: session!,
                sessions: sessions,
                isDelegate: _isDelegate,
                onSelectSession: (id) => setState(() => _selectedId = id),
                onOpenSubject: (subject) => _openSubject(session, subject),
              ),
            ),
            _ => const ProtoPageLoader(label: 'Partiels'),
          },
        );
      },
    );
  }

  ExamSession? _selected(List<ExamSession> sessions) {
    if (sessions.isEmpty) return null;
    return sessions.firstWhere(
      (x) => x.id == _selectedId,
      orElse: () =>
          sessions.firstWhere((x) => x.isOpen, orElse: () => sessions.first),
    );
  }

  Future<List<ExamSession>> _load() async {
    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    return appScope.examRepository.listSessions(accessToken: accessToken);
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _openSubject(
    ExamSession session,
    ExamSubjectSummary subject,
  ) async {
    final index = session.subjects.indexOf(subject);
    await ExamSubjectPage.open(
      context,
      examSubjectId: subject.id,
      palette: SubjectPalette.at(index),
    );
    if (mounted) await _refresh();
  }

  Future<void> _createSession() async {
    final saved = await ExamSessionFormPage.open(context);
    if (saved != null && mounted) {
      setState(() => _selectedId = saved.id);
      await _refresh();
    }
  }

  Future<void> _editSession(ExamSession session) async {
    final saved = await ExamSessionFormPage.open(context, session: session);
    if (!mounted) return;
    if (saved == null) {
      // Supprimés depuis le formulaire, ou rien n'a changé.
      await _refresh();
      return;
    }
    setState(() => _selectedId = saved.id);
    await _refresh();
  }
}

class _SessionView extends StatelessWidget {
  const _SessionView({
    required this.session,
    required this.sessions,
    required this.isDelegate,
    required this.onSelectSession,
    required this.onOpenSubject,
  });

  final ExamSession session;
  final List<ExamSession> sessions;
  final bool isDelegate;
  final ValueChanged<String> onSelectSession;
  final ValueChanged<ExamSubjectSummary> onOpenSubject;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
      children: [
        if (sessions.length > 1) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in sessions)
                ChoiceChip(
                  label: Text(item.title),
                  selected: item.id == session.id,
                  onSelected: (_) => onSelectSession(item.id),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        ExamCountdownHeader(session: session),
        if (!session.isOpen) ...[
          const SizedBox(height: 12),
          _PreparationBanner(session: session),
        ],
        const SizedBox(height: 22),
        ProtoSectionHeading(
          overline: 'Fiches de révision',
          title: session.subjects.length > 1
              ? '${session.subjects.length} matières à réviser'
              : '1 matière à réviser',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 560 ? 3 : 2;
            const spacing = 12.0;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (var i = 0; i < session.subjects.length; i++)
                  SizedBox(
                    width: width,
                    child: _SubjectTile(
                      subject: session.subjects[i],
                      palette: SubjectPalette.at(i),
                      onTap: () => onOpenSubject(session.subjects[i]),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        const _HowItWorks(),
      ],
    );
  }
}

class _SubjectTile extends StatelessWidget {
  const _SubjectTile({
    required this.subject,
    required this.palette,
    required this.onTap,
  });

  final ExamSubjectSummary subject;
  final SubjectPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = palette.accent(context);

    return Material(
      color: context.sfCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: context.sfLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('exam-subject-${subject.id}'),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: palette.soft(context),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Text(
                subject.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.sfText,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.event_outlined, size: 15, color: accent),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          examSlotLabel(subject.examDay, subject.startsAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.sfText,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${subject.itemCount} point${subject.itemCount > 1 ? 's' : ''}',
                              style: TextStyle(
                                color: context.sfMuted,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${subject.resourceCount} ressource${subject.resourceCount > 1 ? 's' : ''}',
                              style: TextStyle(
                                color: context.sfMuted,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              subject.contributorCount == 0
                                  ? 'À lancer'
                                  : '${subject.contributorCount} contributeur${subject.contributorCount > 1 ? 's' : ''}',
                              style: TextStyle(
                                color: context.sfMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ProgressRing(
                        value: subject.progress,
                        color: accent,
                        size: 46,
                        label: subject.itemCount == 0 ? '–' : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreparationBanner extends StatelessWidget {
  const _PreparationBanner({required this.session});

  final ExamSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.sfSharedSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_off_outlined, color: context.sfShared),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'En préparation : la classe verra cette fiche à partir du ${StudyFlowFormat.longDay(session.opensOn).toLowerCase()}. Tu peux déjà la compléter.',
              style: TextStyle(
                color: context.sfText,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    return ProtoCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.groups_2_outlined, color: context.sfShared, size: 20),
              const SizedBox(width: 8),
              Text(
                'Une fiche remplie par toute la classe',
                style: TextStyle(
                  color: context.sfText,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const ProtoMutedText(
            'Chacun ajoute ce qu’il faut réviser, des liens (artefacts Claude, vidéos, documents) ou des fichiers. Coche ce que tu as révisé : ta progression n’est visible que par toi.',
          ),
        ],
      ),
    );
  }
}

class _EmptyExams extends StatelessWidget {
  const _EmptyExams({required this.isDelegate, required this.onCreate});

  final bool isDelegate;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
      children: [
        Icon(Icons.school_outlined, size: 56, color: context.sfShared),
        const SizedBox(height: 16),
        Text(
          isDelegate ? 'Prépare les partiels' : 'Pas de partiels en vue',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.sfText,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isDelegate
              ? 'Indique les dates et les matières. Deux semaines avant, une fiche de révision s’ouvre pour toute la classe.'
              : 'La fiche de révision s’ouvre automatiquement deux semaines avant les partiels, dès que les délégués les ont indiqués.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.sfMuted, fontSize: 15, height: 1.4),
        ),
        if (isDelegate) ...[
          const SizedBox(height: 24),
          Center(
            child: FilledButton.icon(
              key: const ValueKey('exam-create-button'),
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Préparer les partiels'),
            ),
          ),
        ],
      ],
    );
  }
}
