import 'dart:async';

import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/core/widgets/date_time_pickers.dart';
import 'package:studyflow_app/features/groups/data/group_realtime.dart';
import 'package:studyflow_app/features/groups/domain/group_models.dart';
import 'package:studyflow_app/features/groups/presentation/group_widgets.dart';

/// Tâches du groupe : qui fait quoi, pour quand. Celles qu'on me confie
/// arrivent aussi dans mon agenda.
class GroupTasksTab extends StatefulWidget {
  const GroupTasksTab({
    required this.group,
    required this.onChanged,
    super.key,
  });

  final StudyGroupDetail group;

  /// Le compteur d'avancement du groupe a changé.
  final Future<void> Function() onChanged;

  @override
  State<GroupTasksTab> createState() => _GroupTasksTabState();
}

class _GroupTasksTabState extends State<GroupTasksTab>
    with AutomaticKeepAliveClientMixin {
  List<GroupTask>? _tasks;
  String? _error;
  bool _onlyMine = false;
  StreamSubscription<GroupRealtimeEvent>? _subscription;

  String get _groupId => widget.group.summary.id;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_subscription != null) return;
    _subscription = AppScope.of(context).groupRealtime.events
        .where((x) => x.groupId == _groupId)
        .where(
          (x) =>
              x is GroupChangedEvent &&
              (x.area == 'tasks' ||
                  x.area == 'members' ||
                  x.area == 'reconnected'),
        )
        .listen((_) => unawaited(_load()));
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<String?> _token() =>
      AppScope.of(context).sessionController.accessTokenForApi();

  Future<void> _load() async {
    final repository = AppScope.of(context).groupRepository;
    try {
      final tasks = await repository.listTasks(
        groupId: _groupId,
        accessToken: await _token(),
      );
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _error = null;
        });
      }
    } on Exception catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tasks = _tasks;
    if (tasks == null) {
      return _error == null
          ? const Center(child: CircularProgressIndicator())
          : ProtoStateCard(
              icon: Icons.cloud_off_outlined,
              title: 'Tâches indisponibles',
              message: _error!,
              actionLabel: 'Réessayer',
              onAction: _load,
            );
    }

    final visible = _onlyMine ? tasks.where((x) => x.isMine).toList() : tasks;
    final done = tasks.where((x) => x.isDone).length;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: widget.group.summary.isArchived
          ? null
          : FloatingActionButton.extended(
              heroTag: 'group-tasks-fab',
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              key: const ValueKey('group-task-add'),
              backgroundColor: context.sfGroup,
              foregroundColor: context.sfCard,
              onPressed: () => _edit(null),
              icon: const Icon(Icons.add_task),
              label: const Text('Tâche'),
            ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
          children: [
            _ProgressHeader(
              group: widget.group,
              done: done,
              total: tasks.length,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Toutes'),
                  selected: !_onlyMine,
                  onSelected: (_) => setState(() => _onlyMine = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  key: const ValueKey('group-tasks-mine'),
                  label: const Text('Les miennes'),
                  selected: _onlyMine,
                  onSelected: (_) => setState(() => _onlyMine = true),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              ProtoStateCard(
                icon: Icons.checklist_outlined,
                title: _onlyMine ? 'Rien pour toi' : 'Aucune tâche',
                message: _onlyMine
                    ? 'Aucune tâche ne t’est confiée pour l’instant.'
                    : 'Découpez le travail : chaque tâche a un ou plusieurs '
                          'responsables et une échéance.',
                compact: true,
              ),
            for (final status in GroupTaskStatus.values)
              if (visible.any((x) => x.status == status)) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 8),
                  child: ProtoOverline(
                    '${status.label} · ${visible.where((x) => x.status == status).length}',
                  ),
                ),
                for (final task in visible.where((x) => x.status == status))
                  _TaskTile(
                    task: task,
                    late: task.isLate(now),
                    onToggle: () => _setStatus(task, task.status.next),
                    onTap: () => _edit(task),
                  ),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _setStatus(GroupTask task, GroupTaskStatus status) async {
    final repository = AppScope.of(context).groupRepository;
    final index = _tasks!.indexWhere((x) => x.id == task.id);
    setState(() => _tasks![index] = task.copyWith(status: status));
    try {
      await repository.setTaskStatus(
        taskId: task.id,
        status: status,
        accessToken: await _token(),
      );
      unawaited(widget.onChanged());
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
      await _load();
    }
  }

  Future<void> _edit(GroupTask? task) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _TaskSheet(group: widget.group, task: task),
    );
    if (changed == true && mounted) {
      await _load();
      unawaited(widget.onChanged());
    }
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.group,
    required this.done,
    required this.total,
  });

  final StudyGroupDetail group;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final days = group.summary.daysUntilDue(DateTime.now());
    return ProtoCard(
      margin: EdgeInsets.zero,
      backgroundColor: context.sfGroupSoft,
      borderColor: context.sfGroupSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  total == 0
                      ? 'Pas encore de tâche'
                      : '${(done * 100 / total).round()} % fait',
                  style: TextStyle(
                    color: context.sfGroup,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (days != null && days >= 0)
                Text(
                  days == 0 ? 'Rendu aujourd’hui' : 'J-$days',
                  style: TextStyle(
                    color: days <= 2 ? context.sfEvaluation : context.sfGroup,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GroupProgressBar(done: done, total: total),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.late,
    required this.onToggle,
    required this.onTap,
  });

  final GroupTask task;
  final bool late;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (task.status) {
      GroupTaskStatus.todo => (Icons.radio_button_unchecked, context.sfMuted),
      GroupTaskStatus.doing => (Icons.timelapse, context.sfGroup),
      GroupTaskStatus.done => (Icons.check_circle, AppColors.green),
    };

    return ProtoCard(
      key: ValueKey('group-task-${task.id}'),
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
      margin: const EdgeInsets.only(bottom: 8),
      borderColor: task.isMine && !task.isDone
          ? context.sfGroup.withValues(alpha: 0.5)
          : AppColors.line,
      child: Row(
        children: [
          IconButton(
            key: ValueKey('group-task-toggle-${task.id}'),
            tooltip: 'Passer à « ${task.status.next.label} »',
            onPressed: onToggle,
            icon: Icon(icon, color: color),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: task.isDone ? context.sfMuted : context.sfText,
                    fontWeight: FontWeight.w700,
                    decoration: task.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (task.assigneeNames.isEmpty)
                      'Personne'
                    else
                      task.assigneeNames.join(', '),
                    if (task.dueOn case final due?)
                      'pour le ${StudyFlowFormat.shortDay(due)}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: late ? AppColors.danger : context.sfMuted,
                    fontSize: 12,
                    fontWeight: late ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (task.assigneeNames.isNotEmpty)
            GroupAvatar(
              initials: initialsOf(task.assigneeNames.first),
              size: 26,
              highlighted: task.isMine,
            ),
        ],
      ),
    );
  }
}

/// Créer ou modifier une tâche : titre, responsables, échéance, notes.
class _TaskSheet extends StatefulWidget {
  const _TaskSheet({required this.group, this.task});

  final StudyGroupDetail group;
  final GroupTask? task;

  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
  late final _title = TextEditingController(text: widget.task?.title ?? '');
  late final _notes = TextEditingController(text: widget.task?.notes ?? '');
  late final Set<String> _assignees = {
    ...?widget.task?.assigneeIds,
    if (widget.task == null) ?widget.group.me?.userId,
  };
  late DateTime? _dueOn = widget.task?.dueOn;
  late GroupTaskStatus _status = widget.task?.status ?? GroupTaskStatus.todo;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.task != null;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProtoSectionHeading(
                title: isEditing ? 'Modifier la tâche' : 'Nouvelle tâche',
                trailing: isEditing
                    ? IconButton(
                        key: const ValueKey('group-task-delete'),
                        tooltip: 'Supprimer',
                        onPressed: _saving ? null : _delete,
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.danger,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('group-task-title'),
                controller: _title,
                autofocus: !isEditing,
                maxLength: 160,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'À faire',
                  hintText: 'Rédiger l’introduction',
                ),
              ),
              const ProtoFormLabel('Qui s’en occupe ?'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final member in widget.group.activeMembers)
                    FilterChip(
                      key: ValueKey('group-task-assignee-${member.userId}'),
                      avatar: GroupAvatar(initials: member.initials, size: 22),
                      label: Text(member.isMe ? 'Moi' : member.name),
                      selected: _assignees.contains(member.userId),
                      selectedColor: context.sfGroupSoft,
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _assignees.add(member.userId);
                        } else {
                          _assignees.remove(member.userId);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ProtoPickerField(
                keyValue: 'group-task-due',
                icon: Icons.event_outlined,
                label: 'Échéance (optionnel)',
                value: _dueOn == null
                    ? 'Pas d’échéance'
                    : StudyFlowFormat.longDay(_dueOn!),
                onTap: _pickDue,
              ),
              if (isEditing) ...[
                const ProtoFormLabel('Statut'),
                SegmentedButton<GroupTaskStatus>(
                  segments: [
                    for (final status in GroupTaskStatus.values)
                      ButtonSegment(value: status, label: Text(status.label)),
                  ],
                  selected: {_status},
                  onSelectionChanged: (value) =>
                      setState(() => _status = value.first),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notes (optionnel)',
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              FilledButton(
                key: const ValueKey('group-task-save'),
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDue() async {
    final picked = await StudyFlowPickers.pickDate(
      context,
      initialDate: _dueOn ?? DateTime.now().add(const Duration(days: 3)),
      helpText: 'Échéance de la tâche',
    );
    if (picked != null && mounted) setState(() => _dueOn = picked);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Écris la tâche à faire.');
      return;
    }
    final appScope = AppScope.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    final draft = GroupTaskDraft(
      title: _title.text,
      notes: _notes.text,
      dueOn: _dueOn,
      assigneeIds: _assignees.toList(),
      status: widget.task == null ? null : _status,
    );
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      final task = widget.task;
      if (task == null) {
        await appScope.groupRepository.createTask(
          groupId: widget.group.summary.id,
          draft: draft,
          accessToken: accessToken,
        );
      } else {
        await appScope.groupRepository.updateTask(
          taskId: task.id,
          draft: draft,
          accessToken: accessToken,
        );
      }
      navigator.pop(true);
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _delete() async {
    final appScope = AppScope.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      await appScope.groupRepository.deleteTask(
        taskId: widget.task!.id,
        accessToken: accessToken,
      );
      navigator.pop(true);
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$error';
        });
      }
    }
  }
}
