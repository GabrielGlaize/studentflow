import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/features/agenda/domain/agenda_models.dart';

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
      child: Column(
        children: [
          ProtoScreenTitle(
            title: 'Agenda et tâches',
            subtitle: hasCompany
                ? 'Sépare le scolaire et ton espace carrière.'
                : 'Sépare le scolaire et ta recherche d’alternance.',
            trailing: ProtoActionButton(
              icon: Icons.add,
              tooltip: 'Ajouter',
              onPressed: _openCreateMenu,
            ),
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
                        spacing: 7,
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
                    OutlinedButton.icon(
                      onPressed: _openCreateMenu,
                      icon: const Icon(Icons.add, size: 17),
                      label: const Text('Ajouter'),
                    ),
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
                          title: 'Devoirs de classe',
                          count: agenda.homework.length,
                          color: AppColors.rose,
                        ),
                        if (agenda.homework.isEmpty)
                          const _EmptyCard(text: 'Aucun devoir à venir.')
                        else
                          ...agenda.homework.map(
                            (item) => _HomeworkCard(
                              homework: item,
                              onEdit: () => _openHomeworkSheet(item),
                              onDelete: () => _confirmDeleteHomework(item),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                      _SectionTitle(
                        title: _eventSectionTitle,
                        count: agenda.events.length,
                        color: _categoryColor,
                      ),
                      if (agenda.events.isEmpty)
                        const _EmptyCard(
                          text: 'Aucun événement personnel prévu.',
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
                        color: _categoryColor,
                      ),
                      if (agenda.tasks.isEmpty)
                        const _EmptyCard(text: 'Aucune tâche dans cet espace.')
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
      'company' => 'Planning entreprise',
      'apprenticeship' => 'Planning alternance',
      _ => 'Planning école',
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

  Future<void> _openTaskDetails(AgendaTaskItem task) {
    return showModalBottomSheet<void>(
      context: context,
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
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _HomeworkFormSheet(homework: homework),
    );

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
    final workspaceName = switch (category) {
      'company' => 'entreprise',
      'apprenticeship' => 'alternance',
      _ => 'école',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ProtoSectionHeading(
              overline: 'Agenda',
              title: 'Que veux-tu ajouter ?',
            ),
            const SizedBox(height: 14),
            if (isSchool)
              _CreateMenuTile(
                icon: Icons.assignment_outlined,
                title: 'Devoir de classe',
                subtitle: 'Visible par tous les élèves approuvés.',
                onTap: () =>
                    Navigator.pop(context, _AgendaCreateAction.homework),
              ),
            _CreateMenuTile(
              icon: Icons.event_available_outlined,
              title: 'Événement $workspaceName',
              subtitle: 'Entretien, relance, rendez-vous ou moment important.',
              onTap: () => Navigator.pop(context, _AgendaCreateAction.event),
            ),
            _CreateMenuTile(
              icon: Icons.checklist_outlined,
              title: 'Tâche $workspaceName',
              subtitle: 'Visible uniquement dans cet espace.',
              onTap: () => Navigator.pop(context, _AgendaCreateAction.task),
            ),
            if (!isSchool)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ProtoMutedText(
                  hasCompany
                      ? 'Les devoirs de classe restent dans l’espace École.'
                      : 'Les devoirs de classe restent dans l’espace École.',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CreateMenuTile extends StatelessWidget {
  const _CreateMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ProtoCard(
      onTap: onTap,
      child: Row(
        children: [
          ProtoIconBox(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.sfText,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
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
        color: const Color(0xFFDFE9EF),
        borderRadius: BorderRadius.circular(19),
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
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.petrol.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? AppColors.petrol : AppColors.muted,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isActive ? AppColors.petrol : AppColors.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
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
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: selected ? AppColors.petrol : Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.muted,
        fontWeight: FontWeight.w800,
        fontSize: 10,
      ),
      side: BorderSide(color: selected ? AppColors.petrol : AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
    );
  }
}

class _CreateTaskSheet extends StatefulWidget {
  const _CreateTaskSheet({required this.category});

  final String category;

  @override
  State<_CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _TaskDetailsSheet extends StatelessWidget {
  const _TaskDetailsSheet({
    required this.task,
    required this.color,
    required this.onDelete,
  });

  final AgendaTaskItem task;
  final Color color;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
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
                backgroundColor: color.withValues(alpha: 0.16),
                foregroundColor: color,
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
              task.notificationsEnabled ? 'Rappel actif' : 'Aucun rappel',
              task.isDone ? 'Terminée' : 'À faire',
            ].join(' · '),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fermer'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Supprimer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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

class _CreateTaskSheetState extends State<_CreateTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _notificationsEnabled = false;
  bool _isSaving = false;

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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  ProtoIconBox(icon: Icons.add_task_outlined),
                  SizedBox(width: 12),
                  Expanded(
                    child: ProtoSectionHeading(
                      overline: 'Organisation',
                      title: 'Nouvelle tâche',
                    ),
                  ),
                ],
              ),
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
              const SizedBox(height: 10),
              ProtoCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _notificationsEnabled,
                  onChanged: (value) =>
                      setState(() => _notificationsEnabled = value),
                  title: const Text(
                    'Activer le rappel',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('Utile pour les rendus importants.'),
                ),
              ),
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
          notificationsEnabled: _notificationsEnabled,
        ),
      );

      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const ProtoIconBox(icon: Icons.event_available_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ProtoSectionHeading(
                      overline: _eventOverline(widget.category),
                      title: _isEditing
                          ? 'Modifier l’événement'
                          : 'Nouvel événement',
                    ),
                  ),
                ],
              ),
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
              ProtoCard(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    _PickerLine(
                      icon: Icons.calendar_month_outlined,
                      title: 'Date',
                      value: _shortDateLabel(_day),
                      onTap: _pickDay,
                    ),
                    const Divider(height: 1, color: AppColors.line),
                    _PickerLine(
                      icon: Icons.schedule_outlined,
                      title: 'Début',
                      value: _formatTime(_startsAt),
                      onTap: () => _pickTime(isStart: true),
                    ),
                    const Divider(height: 1, color: AppColors.line),
                    _PickerLine(
                      icon: Icons.timer_outlined,
                      title: 'Fin',
                      value: _formatTime(_endsAt),
                      onTap: () => _pickTime(isStart: false),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ProtoCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _notificationsEnabled,
                  onChanged: (value) =>
                      setState(() => _notificationsEnabled = value),
                  title: const Text(
                    'Activer le rappel',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'Pratique pour les entretiens, relances ou rendez-vous.',
                  ),
                ),
              ),
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
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (picked == null) return;
    setState(() => _day = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startsAt : _endsAt,
    );

    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startsAt = picked;
        if (_minutes(_endsAt) <= _minutes(_startsAt)) {
          _endsAt = _addMinutes(_startsAt, 60);
        }
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

class _PickerLine extends StatelessWidget {
  const _PickerLine({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: context.sfIcon),
      title: Text(
        title,
        style: TextStyle(
          color: context.sfText,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
      trailing: TextButton(onPressed: onTap, child: Text(value)),
      onTap: onTap,
    );
  }
}

class _HomeworkFormSheet extends StatefulWidget {
  const _HomeworkFormSheet({this.homework});

  final HomeworkItem? homework;

  @override
  State<_HomeworkFormSheet> createState() => _HomeworkFormSheetState();
}

class _HomeworkFormSheetState extends State<_HomeworkFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late DateTime _deadline;
  bool _isSaving = false;

  bool get _isEditing => widget.homework != null;

  @override
  void initState() {
    super.initState();
    final homework = widget.homework;
    _titleController.text = homework?.title ?? '';
    _descriptionController.text = homework?.description ?? '';
    _deadline =
        homework?.deadline ?? DateTime.now().add(const Duration(days: 1));
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const ProtoIconBox(icon: Icons.assignment_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ProtoSectionHeading(
                      overline: 'Classe',
                      title: _isEditing
                          ? 'Modifier le devoir'
                          : 'Nouveau devoir',
                    ),
                  ),
                ],
              ),
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
              ProtoCard(
                margin: EdgeInsets.zero,
                child: Row(
                  children: [
                    const ProtoIconBox(
                      icon: Icons.event_outlined,
                      backgroundColor: AppColors.roseSoft,
                      foregroundColor: AppColors.rose,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Échéance',
                            style: TextStyle(
                              color: context.sfText,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          ProtoMutedText(_deadlineLabel(_deadline)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _pickDeadline,
                      child: const Text('Changer'),
                    ),
                  ],
                ),
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

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (picked == null) return;
    setState(() {
      _deadline = DateTime(picked.year, picked.month, picked.day, 18);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    final request = CreateHomeworkRequest(
      title: _titleController.text.trim(),
      description: _cleanOptional(_descriptionController.text),
      deadline: _deadline,
      courseId: widget.homework?.courseId,
    );

    try {
      if (widget.homework == null) {
        await appScope.agendaRepository.createHomework(
          request: request,
          accessToken: accessToken,
        );
      } else {
        await appScope.agendaRepository.updateHomework(
          homeworkId: widget.homework!.id,
          request: request,
          accessToken: accessToken,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.count,
    required this.color,
  });

  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: context.sfText,
                fontSize: 14,
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 22),
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : const Color(0xFFE1EBF0),
              borderRadius: BorderRadius.circular(8),
              border: isDark
                  ? Border.all(color: Colors.white.withValues(alpha: 0.14))
                  : null,
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.82)
                    : context.sfMuted,
                fontSize: 9,
                fontWeight: FontWeight.w900,
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
  });

  final HomeworkItem homework;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return _AgendaItemShell(
      color: AppColors.rose,
      backgroundColor: _isUrgent(homework.deadline)
          ? AppColors.roseSoft
          : Colors.white,
      leading: _DateTile(date: homework.deadline, color: AppColors.roseSoft),
      label: 'COLLECTIF',
      title: homework.title,
      subtitle:
          '${_deadlineLabel(homework.deadline)}'
          '${homework.description == null ? '' : ' · ${homework.description}'}',
      trailing: Icon(
        homework.notificationsEnabled
            ? Icons.notifications_active_outlined
            : Icons.notifications_off_outlined,
        size: 18,
        color: context.sfChevron,
      ),
      isDone: homework.isDone,
      menu: PopupMenuButton<_HomeworkAction>(
        tooltip: 'Actions devoir',
        onSelected: (action) {
          switch (action) {
            case _HomeworkAction.edit:
              onEdit();
            case _HomeworkAction.delete:
              onDelete();
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: _HomeworkAction.edit, child: Text('Modifier')),
          PopupMenuItem(
            value: _HomeworkAction.delete,
            child: Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  bool _isUrgent(DateTime deadline) {
    return deadline.difference(DateTime.now()).inDays <= 1;
  }
}

enum _HomeworkAction { edit, delete }

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
      color: color,
      backgroundColor: color.withValues(alpha: 0.08),
      leading: _DateTile(date: event.day, color: AppColors.greenSoft),
      label: _eventCategoryLabel(event.category),
      title: event.title,
      subtitle:
          '${_eventTimeLabel(event)}'
          '${event.location == null ? '' : ' · ${event.location}'}'
          '${event.notes == null ? '' : ' · ${event.notes}'}',
      trailing: Icon(
        event.notificationsEnabled
            ? Icons.notifications_active_outlined
            : Icons.notifications_off_outlined,
        size: 18,
        color: context.sfChevron,
      ),
      menu: PopupMenuButton<_PersonalEventAction>(
        tooltip: 'Actions événement',
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
    return _AgendaItemShell(
      onTap: onOpenDetails,
      color: color,
      leading: InkWell(
        onTap: onToggleDone,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          key: ValueKey('task-done-${task.id}'),
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(top: 3),
          decoration: BoxDecoration(
            color: task.isDone ? AppColors.green : context.sfCard,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: task.isDone ? AppColors.green : AppColors.blueGray,
              width: 2,
            ),
          ),
          child: task.isDone
              ? const Icon(Icons.check, color: Colors.white, size: 14)
              : null,
        ),
      ),
      label: _taskCategoryLabel(task.category),
      title: task.title,
      subtitle:
          '${task.deadline == null ? 'Sans échéance' : _deadlineLabel(task.deadline!)}'
          '${task.description == null ? '' : ' · ${task.description}'}',
      trailing: IconButton(
        key: ValueKey('task-delete-${task.id}'),
        tooltip: 'Supprimer',
        onPressed: onDelete,
        icon: const Icon(Icons.more_horiz),
        color: context.sfChevron,
      ),
      isDone: task.isDone,
    );
  }
}

class _AgendaItemShell extends StatelessWidget {
  const _AgendaItemShell({
    required this.leading,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.color,
    this.backgroundColor = Colors.white,
    this.isDone = false,
    this.onTap,
    this.menu,
  });

  final Widget leading;
  final String label;
  final String title;
  final String subtitle;
  final Widget trailing;
  final Color color;
  final Color backgroundColor;
  final bool isDone;
  final VoidCallback? onTap;
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    return ProtoCard(
      onTap: onTap,
      backgroundColor: backgroundColor,
      padding: const EdgeInsets.fromLTRB(10, 13, 8, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Opacity(
              opacity: isDone ? 0.55 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ProtoChip(
                        label: label,
                        backgroundColor: color.withValues(alpha: 0.14),
                        foregroundColor: color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    title,
                    style: TextStyle(
                      color: context.sfText,
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: FontWeight.w900,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ProtoMutedText(subtitle, maxLines: 2),
                ],
              ),
            ),
          ),
          menu ?? trailing,
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.date, required this.color});

  final DateTime date;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark && color.computeLuminance() > 0.72
        ? AppColors.petrolDark
        : context.sfText;

    return Container(
      width: 45,
      height: 51,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}'.padLeft(2, '0'),
            style: TextStyle(
              color: textColor,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _monthLabel(date),
            style: TextStyle(
              color: textColor.withValues(alpha: 0.78),
              fontSize: 8,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ProtoStateCard(
      icon: Icons.inbox_outlined,
      title: text,
      message: 'Ajoute un élément quand tu veux reprendre le fil.',
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

String _taskCategoryLabel(String category) {
  return switch (category) {
    'company' => 'ENTREPRISE',
    'apprenticeship' => 'ALTERNANCE',
    _ => 'PERSONNEL',
  };
}

String _eventCategoryLabel(String category) {
  return switch (category) {
    'company' => 'RENDEZ-VOUS ENTREPRISE',
    'apprenticeship' => 'PLANNING ALTERNANCE',
    _ => 'ÉVÉNEMENT PERSO',
  };
}
