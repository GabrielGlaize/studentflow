import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/core/widgets/date_time_pickers.dart';
import 'package:studyflow_app/core/widgets/reminder_picker.dart';
import 'package:studyflow_app/features/agenda/domain/agenda_models.dart';
import 'package:studyflow_app/features/agenda/presentation/homework_form_page.dart';

class AgendaPage extends StatefulWidget {
  const AgendaPage({this.initialCategory = 'school', super.key});

  final String initialCategory;

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  late String _category;
  bool _includeDone = false;
  Future<AgendaSummary>? _agendaFuture;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _agendaFuture ??= _loadAgenda();
  }

  @override
  void didUpdateWidget(covariant AgendaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCategory == oldWidget.initialCategory) return;

    setState(() {
      _category = widget.initialCategory;
      _agendaFuture = _loadAgenda();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasCompany = AppScope.of(context).settingsController.hasCompany;
    if (hasCompany && _category == 'apprenticeship') {
      _category = 'company';
    } else if (!hasCompany && _category == 'company') {
      _category = 'apprenticeship';
    }

    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              ProtoScreenTitle(
                title: 'Agenda',
                subtitle: hasCompany
                    ? 'Devoirs de la classe et organisation perso.'
                    : 'Devoirs de la classe et recherche d’alternance.',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                child: Column(
                  children: [
                    _WorkspaceSwitch(
                      selected: _category,
                      hasCompany: hasCompany,
                      onChanged: (value) {
                        setState(() {
                          _category = value;
                          _agendaFuture = _loadAgenda();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            children: [
                              _FilterPill(
                                label: 'À faire',
                                selected: !_includeDone,
                                onTap: () {
                                  setState(() {
                                    _includeDone = false;
                                    _agendaFuture = _loadAgenda();
                                  });
                                },
                              ),
                              _FilterPill(
                                label: 'Terminées',
                                selected: _includeDone,
                                onTap: () {
                                  setState(() {
                                    _includeDone = true;
                                    _agendaFuture = _loadAgenda();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const _VisibilityLegend(),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<AgendaSummary>(
                  future: _agendaFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const ProtoPageLoader(label: 'Agenda');
                    }

                    if (snapshot.hasError) {
                      return _AgendaError(onRetry: _refresh);
                    }

                    final agenda = snapshot.requireData;
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 112),
                        children: [
                          if (_category == 'school') ...[
                            _SectionTitle(
                              title: 'Devoirs de la classe',
                              count: agenda.homework.length,
                              shared: true,
                            ),
                            if (agenda.homework.isEmpty)
                              const _EmptyCard(
                                text: 'Aucun devoir à venir',
                                message:
                                    'Ajoute un devoir depuis ce bouton ou depuis un cours du planning.',
                              )
                            else
                              ...agenda.homework.map(
                                (item) => _HomeworkCard(
                                  homework: item,
                                  onEdit: () => _openHomeworkSheet(item),
                                  onDelete: () => _confirmDeleteHomework(item),
                                  onToggleDone: () =>
                                      _setHomeworkDone(item, !item.isDone),
                                  onEditReminder: () =>
                                      _editHomeworkReminder(item),
                                ),
                              ),
                            const SizedBox(height: 16),
                          ],
                          _SectionTitle(
                            title: _eventSectionTitle,
                            count: agenda.events.length,
                            shared: false,
                          ),
                          if (agenda.events.isEmpty)
                            const _EmptyCard(
                              text: 'Aucun événement prévu',
                              message:
                                  'Rendez-vous, entretien, révision : visible uniquement par toi.',
                            )
                          else
                            ...agenda.events.map(
                              (item) => _PersonalEventCard(
                                event: item,
                                color: _categoryColor,
                                onEdit: () => _openEventSheet(item),
                                onDelete: () => _confirmDeleteEvent(item),
                              ),
                            ),
                          const SizedBox(height: 16),
                          _SectionTitle(
                            title: 'Mes tâches',
                            count: agenda.tasks.length,
                            shared: false,
                          ),
                          if (agenda.tasks.isEmpty)
                            const _EmptyCard(
                              text: 'Aucune tâche',
                              message:
                                  'Tes tâches restent visibles uniquement par toi.',
                            )
                          else
                            ...agenda.tasks.map(
                              (item) => _TaskCard(
                                task: item,
                                color: _categoryColor,
                                onOpenDetails: () => _openTaskDetails(item),
                                onToggleDone: () =>
                                    _setTaskDone(item, isDone: !item.isDone),
                                onDelete: () => _confirmDeleteTask(item),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Center(
              child: FloatingActionButton.extended(
                key: const ValueKey('agenda-add-button'),
                heroTag: 'agenda-add',
                backgroundColor: context.sfAccent,
                foregroundColor: context.sfOnAccent,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                onPressed: _openCreateMenu,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color get _categoryColor {
    return switch (_category) {
      'company' => AppColors.green,
      'apprenticeship' => const Color(0xFF4F7891),
      _ => AppColors.petrol,
    };
  }

  String get _eventSectionTitle {
    return switch (_category) {
      'company' => 'Mes rendez-vous entreprise',
      'apprenticeship' => 'Mes rendez-vous alternance',
      _ => 'Mes événements',
    };
  }

  String get _eventCategory {
    return switch (_category) {
      'company' => 'company',
      'apprenticeship' => 'apprenticeship',
      _ => 'personal',
    };
  }

  Future<AgendaSummary> _loadAgenda() async {
    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();

    return appScope.agendaRepository.getAgenda(
      taskCategory: _category,
      includeDone: _includeDone,
      accessToken: accessToken,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _agendaFuture = _loadAgenda();
    });
    await _agendaFuture;
    // Un devoir, une tâche ou un rappel a pu changer.
    if (mounted) AppScope.of(context).reminderSync.requestSync();
  }

  Future<void> _openCreateTaskSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _CreateTaskSheet(category: _category),
    );

    if (created == true && mounted) {
      await _refresh();
    }
  }

  Future<void> _openCreateMenu() async {
    final action = await showModalBottomSheet<_AgendaCreateAction>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _CreateAgendaMenu(
        category: _category,
        hasCompany: AppScope.of(context).settingsController.hasCompany,
      ),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case _AgendaCreateAction.homework:
        await _openHomeworkSheet();
      case _AgendaCreateAction.task:
        await _openCreateTaskSheet();
      case _AgendaCreateAction.event:
        await _openEventSheet();
    }
  }

  Future<void> _openTaskDetails(AgendaTaskItem task) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _TaskDetailsSheet(
        task: task,
        color: _categoryColor,
        onDelete: () {
          Navigator.pop(context);
          _confirmDeleteTask(task);
        },
      ),
    );

    if (changed == true && mounted) await _refresh();
  }

  Future<void> _setHomeworkDone(HomeworkItem homework, bool isDone) async {
    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    await appScope.agendaRepository.updateHomeworkProgress(
      homework: homework,
      isDone: isDone,
      notificationsEnabled: homework.notificationsEnabled,
      reminderMinutesBefore: homework.reminderMinutesBefore,
      accessToken: accessToken,
    );

    if (!mounted) return;
    _showMessage(
      isDone ? 'Devoir marqué comme fait.' : 'Devoir remis à faire.',
    );
    await _refresh();
  }

  Future<void> _editHomeworkReminder(HomeworkItem homework) async {
    final choice = await showModalBottomSheet<(bool, int)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _HomeworkReminderSheet(homework: homework),
    );
    if (choice == null || !mounted) return;

    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    await appScope.agendaRepository.updateHomeworkProgress(
      homework: homework,
      isDone: homework.isDone,
      notificationsEnabled: choice.$1,
      reminderMinutesBefore: choice.$2,
      accessToken: accessToken,
    );

    if (!mounted) return;
    _showMessage(
      choice.$1
          ? 'Rappel : ${ReminderFormat.label(choice.$2).toLowerCase()}.'
          : 'Rappel désactivé pour ce devoir.',
    );
    await _refresh();
  }

  Future<void> _openEventSheet([PersonalEventItem? event]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) =>
          _PersonalEventFormSheet(event: event, category: _eventCategory),
    );

    if (saved == true && mounted) {
      await _refresh();
    }
  }

  Future<void> _openHomeworkSheet([HomeworkItem? homework]) async {
    final saved = await HomeworkFormPage.open(context, homework: homework);

    if (saved == true && mounted) {
      await _refresh();
    }
  }

  Future<void> _setTaskDone(AgendaTaskItem task, {required bool isDone}) async {
    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();

    await appScope.agendaRepository.updateTaskStatus(
      task: task,
      isDone: isDone,
      accessToken: accessToken,
    );

    if (!mounted) return;
    _showMessage(isDone ? 'Tâche terminée.' : 'Tâche restaurée.');
    await _refresh();
  }

  Future<void> _confirmDeleteTask(AgendaTaskItem task) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la tâche ?'),
        content: Text('“${task.title}” sera retirée de ton agenda.'),
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

    await appScope.agendaRepository.deleteTask(
      taskId: task.id,
      accessToken: accessToken,
    );

    if (!mounted) return;
    _showMessage('Tâche supprimée.');
    await _refresh();
  }

  Future<void> _confirmDeleteEvent(PersonalEventItem event) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cet événement ?'),
        content: Text('“${event.title}” sera retiré de ton planning.'),
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

    await appScope.agendaRepository.deleteEvent(
      eventId: event.id,
      accessToken: accessToken,
    );

    if (!mounted) return;
    _showMessage('Événement supprimé.');
    await _refresh();
  }

  Future<void> _confirmDeleteHomework(HomeworkItem homework) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce devoir ?'),
        content: Text('“${homework.title}” sera retiré pour la classe.'),
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

    await appScope.agendaRepository.deleteHomework(
      homeworkId: homework.id,
      accessToken: accessToken,
    );

    if (!mounted) return;
    _showMessage('Devoir supprimé.');
    await _refresh();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _AgendaCreateAction { homework, task, event }

class _CreateAgendaMenu extends StatelessWidget {
  const _CreateAgendaMenu({required this.category, required this.hasCompany});

  final String category;
  final bool hasCompany;

  @override
  Widget build(BuildContext context) {
    final isSchool = category == 'school';
    final eventTitle = switch (category) {
      'company' => 'Rendez-vous entreprise',
      'apprenticeship' => 'Rendez-vous alternance',
      _ => 'Événement',
    };

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Que veux-tu ajouter ?',
              style: TextStyle(
                color: context.sfText,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (isSchool) ...[
              const SizedBox(height: 16),
              const _CreateMenuGroupTitle(shared: true),
              _CreateMenuTile(
                key: const ValueKey('create-homework'),
                shared: true,
                icon: Icons.assignment_outlined,
                title: 'Devoir',
                subtitle: 'Rattaché à un cours, visible par toute la classe.',
                onTap: () =>
                    Navigator.pop(context, _AgendaCreateAction.homework),
              ),
            ],
            const SizedBox(height: 16),
            const _CreateMenuGroupTitle(shared: false),
            _CreateMenuTile(
              key: const ValueKey('create-task'),
              shared: false,
              icon: Icons.check_circle_outline,
              title: 'Tâche',
              subtitle: 'Une chose à faire, avec ou sans échéance.',
              onTap: () => Navigator.pop(context, _AgendaCreateAction.task),
            ),
            _CreateMenuTile(
              key: const ValueKey('create-event'),
              shared: false,
              icon: Icons.event_available_outlined,
              title: eventTitle,
              subtitle: 'Un moment daté : entretien, révision, rendez-vous.',
              onTap: () => Navigator.pop(context, _AgendaCreateAction.event),
            ),
            if (!isSchool)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: ProtoMutedText(
                  'Les devoirs de la classe se créent depuis l’espace École.',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CreateMenuGroupTitle extends StatelessWidget {
  const _CreateMenuGroupTitle({required this.shared});

  final bool shared;

  @override
  Widget build(BuildContext context) {
    final color = shared ? context.sfShared : context.sfPersonal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            shared ? Icons.groups_2_outlined : Icons.lock_outline,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            shared ? 'POUR TOUTE LA CLASSE' : 'RIEN QUE POUR MOI',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateMenuTile extends StatelessWidget {
  const _CreateMenuTile({
    required this.shared,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final bool shared;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = shared ? context.sfShared : context.sfPersonal;
    return ProtoCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ProtoIconBox(
            icon: icon,
            backgroundColor: shared
                ? context.sfSharedSoft
                : context.sfPersonalSoft,
            foregroundColor: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.sfText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                ProtoMutedText(subtitle),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.sfChevron),
        ],
      ),
    );
  }
}

/// Rappel discret du code couleur : bleu = classe, vert = perso.
class _VisibilityLegend extends StatelessWidget {
  const _VisibilityLegend();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProtoVisibilityChip(shared: true),
        SizedBox(width: 6),
        ProtoVisibilityChip(shared: false),
      ],
    );
  }
}

class _WorkspaceSwitch extends StatelessWidget {
  const _WorkspaceSwitch({
    required this.selected,
    required this.hasCompany,
    required this.onChanged,
  });

  final String selected;
  final bool hasCompany;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: context.sfSoftCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.sfLine),
      ),
      child: Row(
        children: [
          _WorkspaceButton(
            icon: Icons.school_outlined,
            title: 'École',
            value: 'school',
            selected: selected,
            onChanged: onChanged,
          ),
          _WorkspaceButton(
            icon: hasCompany ? Icons.work_outline : Icons.search_outlined,
            title: hasCompany ? 'Entreprise' : 'Alternance',
            value: hasCompany ? 'company' : 'apprenticeship',
            selected: selected,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _WorkspaceButton extends StatelessWidget {
  const _WorkspaceButton({
    required this.icon,
    required this.title,
    required this.value,
    required this.selected,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String value;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isActive = value == selected;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? context.sfCard : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive && !context.sfIsDark
                ? [
                    BoxShadow(
                      color: AppColors.petrol.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? context.sfAccent : context.sfMuted,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isActive ? context.sfText : context.sfMuted,
                    fontSize: 15,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
    );
  }
}

class _CreateTaskSheet extends StatefulWidget {
  const _CreateTaskSheet({required this.category});

  final String category;

  @override
  State<_CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _TaskDetailsSheet extends StatefulWidget {
  const _TaskDetailsSheet({
    required this.task,
    required this.color,
    required this.onDelete,
  });

  final AgendaTaskItem task;
  final Color color;
  final VoidCallback onDelete;

  @override
  State<_TaskDetailsSheet> createState() => _TaskDetailsSheetState();
}

class _TaskDetailsSheetState extends State<_TaskDetailsSheet> {
  late AgendaTaskItem _task = widget.task;
  bool _changed = false;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final task = _task;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProtoIconBox(
                  icon: task.isDone
                      ? Icons.check_circle_outline
                      : Icons.checklist_outlined,
                  backgroundColor: widget.color.withValues(alpha: 0.16),
                  foregroundColor: widget.color,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ProtoSectionHeading(
                    overline: _categoryLabel(task.category),
                    title: task.title,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if ((task.description ?? '').trim().isNotEmpty)
              ProtoMutedText(task.description!)
            else
              const ProtoMutedText('Aucune description.'),
            const SizedBox(height: 10),
            ProtoMutedText(
              [
                if (task.deadline != null)
                  'Échéance ${_formatDate(task.deadline!)}',
                task.isDone ? 'Terminée' : 'À faire',
              ].join(' · '),
            ),
            const SizedBox(height: 14),
            AbsorbPointer(
              absorbing: _isSaving,
              child: ReminderSetting(
                enabled: task.notificationsEnabled,
                minutesBefore: task.reminderMinutesBefore,
                reference: task.deadline,
                atMoment: 'À l’heure de l’échéance',
                unavailableReason: task.deadline == null
                    ? 'Cette tâche n’a pas d’échéance.'
                    : null,
                onChanged: _saveReminder,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, _changed),
                    child: const Text('Fermer'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton.icon(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Supprimer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveReminder(bool enabled, int minutes) async {
    final previous = _task;
    setState(() {
      _isSaving = true;
      _task = _task.copyWith(
        notificationsEnabled: enabled,
        reminderMinutesBefore: minutes,
      );
    });

    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      final saved = await appScope.agendaRepository.updateTask(
        task: _task,
        accessToken: accessToken,
      );
      if (mounted) {
        setState(() {
          _task = saved;
          _changed = true;
        });
      }
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _task = previous);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _categoryLabel(String value) {
    return switch (value) {
      'company' => 'Entreprise',
      'apprenticeship' => 'Alternance',
      _ => 'École',
    };
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month à $hour:$minute';
  }
}

/// Rappel personnel d'un devoir de la classe : chacun choisit le sien.
class _HomeworkReminderSheet extends StatefulWidget {
  const _HomeworkReminderSheet({required this.homework});

  final HomeworkItem homework;

  @override
  State<_HomeworkReminderSheet> createState() => _HomeworkReminderSheetState();
}

class _HomeworkReminderSheetState extends State<_HomeworkReminderSheet> {
  late bool _enabled = widget.homework.notificationsEnabled;
  late int _minutes = widget.homework.reminderMinutesBefore;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Mon rappel',
              style: TextStyle(
                color: context.sfText,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            ProtoMutedText(
              '« ${widget.homework.title} » · seul toi reçois ce rappel.',
            ),
            const SizedBox(height: 14),
            ReminderSetting(
              enabled: _enabled,
              minutesBefore: _minutes,
              reference: widget.homework.deadline,
              atMoment: 'À l’heure de l’échéance',
              onChanged: (enabled, minutes) => setState(() {
                _enabled = enabled;
                _minutes = minutes;
              }),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('homework-reminder-save'),
              onPressed: () => Navigator.pop(context, (_enabled, _minutes)),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateTaskSheetState extends State<_CreateTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _notificationsEnabled = false;
  int _reminderMinutes = ReminderDelays.taskDefault;
  DateTime? _deadline;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nouvelle tâche',
                style: TextStyle(
                  color: context.sfText,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const ProtoVisibilityBanner(shared: false),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titre',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  return (value ?? '').trim().isEmpty
                      ? 'Le titre est obligatoire.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description optionnelle',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                minLines: 1,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ProtoPickerField(
                      icon: Icons.event_outlined,
                      label: 'Échéance (optionnel)',
                      value: _deadline == null
                          ? 'Aucune'
                          : '${StudyFlowFormat.shortDay(_deadline!)} · ${StudyFlowFormat.timeOf(_deadline!)}',
                      onTap: _pickDeadline,
                    ),
                  ),
                  if (_deadline != null)
                    IconButton(
                      tooltip: 'Retirer l’échéance',
                      onPressed: () => setState(() {
                        _deadline = null;
                        _notificationsEnabled = false;
                      }),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ReminderSetting(
                enabled: _notificationsEnabled,
                minutesBefore: _reminderMinutes,
                reference: _deadline,
                atMoment: 'À l’heure de l’échéance',
                unavailableReason: _deadline == null
                    ? 'Ajoute une échéance pour recevoir un rappel.'
                    : null,
                onChanged: (enabled, minutes) => setState(() {
                  _notificationsEnabled = enabled;
                  _reminderMinutes = minutes;
                }),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSaving ? null : _save,
                      child: Text(_isSaving ? 'Création...' : 'Créer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();

    try {
      await appScope.agendaRepository.createTask(
        accessToken: accessToken,
        request: CreateAgendaTaskRequest(
          title: _titleController.text.trim(),
          description: _cleanOptional(_descriptionController.text),
          category: widget.category,
          deadline: _deadline,
          notificationsEnabled: _notificationsEnabled && _deadline != null,
          reminderMinutesBefore: _reminderMinutes,
        ),
      );

      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDeadline() async {
    final initial =
        _deadline ??
        DateTime.now()
            .add(const Duration(days: 1))
            .copyWith(hour: 18, minute: 0);
    final day = await StudyFlowPickers.pickDate(
      context,
      initialDate: initial,
      firstDate: DateUtils.dateOnly(DateTime.now()),
      helpText: 'Échéance',
    );
    if (day == null || !mounted) return;
    final time = await StudyFlowPickers.pickTime(
      context,
      initialTime: TimeOfDay.fromDateTime(initial),
      title: 'Heure limite',
    );
    if (!mounted) return;
    final picked = time ?? TimeOfDay.fromDateTime(initial);
    setState(() {
      // Première échéance : le rappel s'active d'office, modifiable ensuite.
      if (_deadline == null) _notificationsEnabled = true;
      _deadline = DateTime(
        day.year,
        day.month,
        day.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  String? _cleanOptional(String value) {
    final cleaned = value.trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

class _PersonalEventFormSheet extends StatefulWidget {
  const _PersonalEventFormSheet({required this.category, this.event});

  final String category;
  final PersonalEventItem? event;

  @override
  State<_PersonalEventFormSheet> createState() =>
      _PersonalEventFormSheetState();
}

class _PersonalEventFormSheetState extends State<_PersonalEventFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  late DateTime _day;
  late TimeOfDay _startsAt;
  late TimeOfDay _endsAt;
  bool _notificationsEnabled = false;
  int _reminderMinutes = ReminderDelays.eventDefault;
  bool _isSaving = false;

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _titleController.text = event?.title ?? '';
    _locationController.text = event?.location ?? '';
    _notesController.text = event?.notes ?? '';
    _day = event?.day ?? DateTime.now();
    _startsAt =
        _parseTime(event?.startsAt) ?? const TimeOfDay(hour: 9, minute: 0);
    _endsAt = _parseTime(event?.endsAt) ?? const TimeOfDay(hour: 10, minute: 0);
    _notificationsEnabled = event?.notificationsEnabled ?? true;
    _reminderMinutes =
        event?.reminderMinutesBefore ?? ReminderDelays.eventDefault;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProtoOverline(_eventOverline(widget.category)),
              const SizedBox(height: 2),
              Text(
                _isEditing ? 'Modifier l’événement' : 'Nouvel événement',
                style: TextStyle(
                  color: context.sfText,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const ProtoVisibilityBanner(shared: false),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titre',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  return (value ?? '').trim().isEmpty
                      ? 'Le titre est obligatoire.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Lieu ou lien optionnel',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes optionnelles',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                minLines: 1,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              ProtoPickerField(
                icon: Icons.calendar_today_outlined,
                label: 'Date',
                value: StudyFlowFormat.longDay(_day),
                onTap: _pickDay,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ProtoPickerField(
                      icon: Icons.schedule_outlined,
                      label: 'Début',
                      value: _formatTime(_startsAt),
                      onTap: () => _pickTime(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ProtoPickerField(
                      icon: Icons.schedule,
                      label: 'Fin',
                      value: _formatTime(_endsAt),
                      onTap: () => _pickTime(isStart: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ReminderSetting(
                enabled: _notificationsEnabled,
                minutesBefore: _reminderMinutes,
                reference: DateTime(
                  _day.year,
                  _day.month,
                  _day.day,
                  _startsAt.hour,
                  _startsAt.minute,
                ),
                referenceLabel: 'Début',
                atMoment: 'Au début',
                onChanged: (enabled, minutes) => setState(() {
                  _notificationsEnabled = enabled;
                  _reminderMinutes = minutes;
                }),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSaving ? null : _save,
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
      ),
    );
  }

  Future<void> _pickDay() async {
    final picked = await StudyFlowPickers.pickDate(
      context,
      initialDate: _day,
      helpText: 'Date de l’événement',
    );

    if (picked == null) return;
    setState(() => _day = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await StudyFlowPickers.pickTime(
      context,
      initialTime: isStart ? _startsAt : _endsAt,
      title: isStart ? 'Début' : 'Fin',
    );

    if (picked == null) return;
    setState(() {
      if (isStart) {
        // Décaler le début garde la même durée.
        final duration = _minutes(_endsAt) - _minutes(_startsAt);
        _startsAt = picked;
        _endsAt = _addMinutes(picked, duration > 0 ? duration : 60);
      } else {
        _endsAt = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_minutes(_endsAt) <= _minutes(_startsAt)) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('L’heure de fin doit être après le début.'),
          ),
        );
      return;
    }

    setState(() => _isSaving = true);
    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    final request = CreatePersonalEventRequest(
      title: _titleController.text.trim(),
      day: _day,
      startsAt: _formatTime(_startsAt),
      endsAt: _formatTime(_endsAt),
      category: widget.category,
      location: _cleanOptional(_locationController.text),
      notes: _cleanOptional(_notesController.text),
      notificationsEnabled: _notificationsEnabled,
      reminderMinutesBefore: _reminderMinutes,
    );

    try {
      if (widget.event == null) {
        await appScope.agendaRepository.createEvent(
          request: request,
          accessToken: accessToken,
        );
      } else {
        await appScope.agendaRepository.updateEvent(
          eventId: widget.event!.id,
          request: request,
          accessToken: accessToken,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  TimeOfDay _addMinutes(TimeOfDay value, int minutes) {
    final total = (_minutes(value) + minutes).clamp(0, 23 * 60 + 59);
    return TimeOfDay(hour: total ~/ 60, minute: total % 60);
  }

  int _minutes(TimeOfDay value) => value.hour * 60 + value.minute;

  String? _cleanOptional(String value) {
    final cleaned = value.trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.count,
    required this.shared,
  });

  final String title;
  final int count;
  final bool shared;

  @override
  Widget build(BuildContext context) {
    final color = shared ? context.sfShared : context.sfPersonal;

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
      child: Row(
        children: [
          Icon(
            shared ? Icons.groups_2_outlined : Icons.lock_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: context.sfText,
                fontSize: 17,
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 26),
            height: 24,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: shared ? context.sfSharedSoft : context.sfPersonalSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeworkCard extends StatelessWidget {
  const _HomeworkCard({
    required this.homework,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleDone,
    required this.onEditReminder,
  });

  final HomeworkItem homework;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleDone;
  final VoidCallback onEditReminder;

  @override
  Widget build(BuildContext context) {
    final urgent = _isUrgent(homework.deadline);
    final courseDay = homework.courseDay;

    return _AgendaItemShell(
      onTap: onEdit,
      shared: true,
      leading: _DateTile(date: homework.deadline, urgent: urgent),
      label: homework.subjectName,
      title: homework.title,
      subtitle: [
        _deadlineLabel(homework.deadline),
        if (courseDay != null)
          'cours du ${StudyFlowFormat.shortDay(courseDay)}',
        ?homework.description,
      ].join(' · '),
      footer: homework.isDone
          ? null
          : _ReminderBadge(
              enabled: homework.notificationsEnabled,
              minutes: homework.reminderMinutesBefore,
              onTap: onEditReminder,
            ),
      isDone: homework.isDone,
      menu: PopupMenuButton<_HomeworkAction>(
        tooltip: 'Actions devoir',
        icon: Icon(Icons.more_vert, color: context.sfChevron),
        onSelected: (action) {
          switch (action) {
            case _HomeworkAction.toggleDone:
              onToggleDone();
            case _HomeworkAction.reminder:
              onEditReminder();
            case _HomeworkAction.edit:
              onEdit();
            case _HomeworkAction.delete:
              onDelete();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _HomeworkAction.toggleDone,
            child: Text(
              homework.isDone ? 'Remettre à faire' : 'Marquer comme fait',
            ),
          ),
          const PopupMenuItem(
            value: _HomeworkAction.reminder,
            child: Text('Mon rappel'),
          ),
          const PopupMenuItem(
            value: _HomeworkAction.edit,
            child: Text('Modifier'),
          ),
          const PopupMenuItem(
            value: _HomeworkAction.delete,
            child: Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  bool _isUrgent(DateTime deadline) {
    return deadline.difference(DateTime.now()).inHours <= 24;
  }
}

enum _HomeworkAction { toggleDone, reminder, edit, delete }

/// « La veille » sous un devoir ou une tâche : touche pour changer le rappel.
class _ReminderBadge extends StatelessWidget {
  const _ReminderBadge({
    required this.enabled,
    required this.minutes,
    this.onTap,
  });

  final bool enabled;
  final int minutes;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? context.sfAccent : context.sfMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              enabled
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              size: 15,
              color: color,
            ),
            const SizedBox(width: 5),
            Text(
              enabled
                  ? 'Rappel : ${ReminderFormat.label(minutes, atMoment: 'à l’échéance').toLowerCase()}'
                  : 'Sans rappel',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonalEventCard extends StatelessWidget {
  const _PersonalEventCard({
    required this.event,
    required this.color,
    required this.onEdit,
    required this.onDelete,
  });

  final PersonalEventItem event;
  final Color color;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return _AgendaItemShell(
      onTap: onEdit,
      shared: false,
      leading: _DateTile(date: event.day),
      label: _eventCategoryLabel(event.category),
      title: event.title,
      subtitle: [
        _eventTimeLabel(event),
        ?event.location,
        ?event.notes,
      ].join(' · '),
      footer: _ReminderBadge(
        enabled: event.notificationsEnabled,
        minutes: event.reminderMinutesBefore,
        onTap: onEdit,
      ),
      menu: PopupMenuButton<_PersonalEventAction>(
        tooltip: 'Actions événement',
        icon: Icon(Icons.more_vert, color: context.sfChevron),
        onSelected: (action) {
          switch (action) {
            case _PersonalEventAction.edit:
              onEdit();
            case _PersonalEventAction.delete:
              onDelete();
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: _PersonalEventAction.edit,
            child: Text('Modifier'),
          ),
          PopupMenuItem(
            value: _PersonalEventAction.delete,
            child: Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

enum _PersonalEventAction { edit, delete }

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.color,
    required this.onOpenDetails,
    required this.onToggleDone,
    required this.onDelete,
  });

  final AgendaTaskItem task;
  final Color color;
  final VoidCallback onOpenDetails;
  final VoidCallback onToggleDone;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = context.sfPersonal;

    return _AgendaItemShell(
      onTap: onOpenDetails,
      shared: false,
      leading: InkWell(
        onTap: onToggleDone,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          key: ValueKey('task-done-${task.id}'),
          width: 46,
          height: 46,
          alignment: Alignment.center,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: task.isDone ? accent : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: task.isDone ? accent : context.sfMuted,
                width: 2,
              ),
            ),
            child: task.isDone
                ? Icon(Icons.check, color: context.sfOnAccent, size: 17)
                : null,
          ),
        ),
      ),
      label: _taskCategoryLabel(task.category),
      title: task.title,
      subtitle: [
        task.deadline == null
            ? 'Sans échéance'
            : _deadlineLabel(task.deadline!),
        ?task.description,
      ].join(' · '),
      footer: task.deadline == null || task.isDone
          ? null
          : _ReminderBadge(
              enabled: task.notificationsEnabled,
              minutes: task.reminderMinutesBefore,
              onTap: onOpenDetails,
            ),
      menu: IconButton(
        key: ValueKey('task-delete-${task.id}'),
        tooltip: 'Supprimer',
        onPressed: onDelete,
        icon: const Icon(Icons.delete_outline),
        color: context.sfChevron,
      ),
      isDone: task.isDone,
    );
  }
}

class _AgendaItemShell extends StatelessWidget {
  const _AgendaItemShell({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.shared,
    required this.menu,
    this.label,
    this.footer,
    this.isDone = false,
    this.onTap,
  });

  final Widget leading;
  final Widget? footer;
  final String? label;
  final String title;
  final String subtitle;
  final bool shared;
  final bool isDone;
  final VoidCallback? onTap;
  final Widget menu;

  @override
  Widget build(BuildContext context) {
    final color = shared ? context.sfShared : context.sfPersonal;

    return ProtoCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Liseré de couleur : bleu pour la classe, vert pour le perso.
            Container(width: 4, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 12, 4, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Opacity(
                        opacity: isDone ? 0.55 : 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                ProtoVisibilityChip(shared: shared),
                                if (label case final text?)
                                  ProtoChip(
                                    label: text,
                                    backgroundColor: context.sfSoftCard,
                                    foregroundColor: context.sfText,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              title,
                              style: TextStyle(
                                color: context.sfText,
                                fontSize: 16,
                                height: 1.3,
                                fontWeight: FontWeight.w700,
                                decoration: isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ProtoMutedText(subtitle, maxLines: 2),
                            if (footer case final widget?) ...[
                              const SizedBox(height: 4),
                              widget,
                            ],
                          ],
                        ),
                      ),
                    ),
                    menu,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.date, this.urgent = false});

  final DateTime date;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final background = urgent
        ? (context.sfIsDark
              ? AppColors.rose.withValues(alpha: 0.22)
              : AppColors.roseSoft)
        : context.sfSoftCard;
    final textColor = urgent && !context.sfIsDark
        ? const Color(0xFF8D5C66)
        : context.sfText;

    return Container(
      width: 46,
      height: 50,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}'.padLeft(2, '0'),
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _monthLabel(date),
            style: TextStyle(
              color: textColor.withValues(alpha: 0.75),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text, required this.message});

  final String text;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ProtoStateCard(
      icon: Icons.inbox_outlined,
      title: text,
      message: message,
      compact: true,
    );
  }
}

class _AgendaError extends StatelessWidget {
  const _AgendaError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ProtoStateCard(
      icon: Icons.cloud_off_outlined,
      title: 'Agenda indisponible',
      message: 'Impossible de charger tes devoirs et tâches.',
      actionLabel: 'Réessayer',
      onAction: onRetry,
    );
  }
}

String _deadlineLabel(DateTime deadline) {
  final day = deadline.day.toString().padLeft(2, '0');
  final month = deadline.month.toString().padLeft(2, '0');
  final hour = deadline.hour.toString().padLeft(2, '0');
  final minute = deadline.minute.toString().padLeft(2, '0');
  return 'Échéance $day/$month à $hour:$minute';
}

String _shortDateLabel(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _formatTime(TimeOfDay value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _eventTimeLabel(PersonalEventItem event) {
  return '${_shortDateLabel(event.day)} · ${event.startsAt}–${event.endsAt}';
}

String _eventOverline(String category) {
  return switch (category) {
    'company' => 'Entreprise',
    'apprenticeship' => 'Alternance',
    _ => 'Personnel',
  };
}

String _monthLabel(DateTime date) {
  const months = [
    'JAN',
    'FÉV',
    'MAR',
    'AVR',
    'MAI',
    'JUN',
    'JUL',
    'AOÛ',
    'SEP',
    'OCT',
    'NOV',
    'DÉC',
  ];
  return months[date.month - 1];
}

String? _taskCategoryLabel(String category) {
  return switch (category) {
    'company' => 'Entreprise',
    'apprenticeship' => 'Alternance',
    _ => null,
  };
}

String? _eventCategoryLabel(String category) {
  return switch (category) {
    'company' => 'Entreprise',
    'apprenticeship' => 'Alternance',
    _ => null,
  };
}
