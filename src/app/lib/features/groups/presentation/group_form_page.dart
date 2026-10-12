import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/core/widgets/date_time_pickers.dart';
import 'package:studyflow_app/features/agenda/domain/agenda_models.dart';
import 'package:studyflow_app/features/classes/domain/class_resource_models.dart';
import 'package:studyflow_app/features/groups/domain/group_models.dart';
import 'package:studyflow_app/features/groups/presentation/group_widgets.dart';
import 'package:studyflow_app/features/groups/presentation/invite_classmates_sheet.dart';

/// Créer un groupe (ou modifier le sien) : nom, devoir et cours liés, date de
/// rendu, puis les camarades à inviter.
class GroupFormPage extends StatefulWidget {
  const GroupFormPage({this.group, this.initialHomework, super.key});

  final StudyGroupDetail? group;

  /// Devoir de groupe depuis lequel on crée le groupe.
  final HomeworkItem? initialHomework;

  static Future<StudyGroupDetail?> open(
    BuildContext context, {
    StudyGroupDetail? group,
    HomeworkItem? homework,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<StudyGroupDetail>(
        builder: (context) =>
            GroupFormPage(group: group, initialHomework: homework),
      ),
    );
  }

  @override
  State<GroupFormPage> createState() => _GroupFormPageState();
}

class _GroupFormPageState extends State<GroupFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  Future<_Choices>? _choicesFuture;
  String? _homeworkId;
  String? _subjectId;
  DateTime? _dueAt;
  List<Classmate> _invitees = const [];
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.group != null;

  @override
  void initState() {
    super.initState();
    final group = widget.group;
    final homework = widget.initialHomework;
    _nameController = TextEditingController(
      text: group?.summary.name ?? (homework == null ? '' : homework.title),
    );
    _descriptionController = TextEditingController(
      text: group?.description ?? '',
    );
    _homeworkId = group?.summary.homeworkId ?? homework?.id;
    _subjectId = group?.summary.subjectId;
    _dueAt = group?.summary.dueAt ?? homework?.deadline.toLocal();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _choicesFuture ??= _loadChoices();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<_Choices> _loadChoices() async {
    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    final results = await Future.wait<Object>([
      appScope.agendaRepository
          .getAgenda(taskCategory: 'school', accessToken: accessToken)
          .then<Object>((x) => x.homework)
          .catchError((Object _) => const <HomeworkItem>[]),
      appScope.classResourceRepository
          .listSubjects(accessToken: accessToken)
          .then<Object>((x) => x)
          .catchError((Object _) => const <ClassSubject>[]),
    ]);
    final homework = [...results[0] as List<HomeworkItem>];
    final initial = widget.initialHomework;
    if (initial != null && homework.every((x) => x.id != initial.id)) {
      homework.insert(0, initial);
    }
    homework.sort((a, b) {
      if (a.isGroupWork != b.isGroupWork) return a.isGroupWork ? -1 : 1;
      return a.deadline.compareTo(b.deadline);
    });
    final subjects = (results[1] as List<ClassSubject>)
        .where((x) => x.isActive || x.id == _subjectId)
        .toList();
    return _Choices(homework: homework, subjects: subjects);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le groupe' : 'Nouveau groupe'),
      ),
      body: FutureBuilder<_Choices>(
        future: _choicesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const ProtoPageLoader(label: 'Préparation');
          }
          final choices = snapshot.requireData;
          final homework = choices.homework
              .where((x) => x.id == _homeworkId)
              .firstOrNull;
          final subject = choices.subjects
              .where((x) => x.id == _subjectId)
              .firstOrNull;

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                const GroupPrivacyBanner(),
                const SizedBox(height: 20),
                TextFormField(
                  key: const ValueKey('group-name-field'),
                  controller: _nameController,
                  maxLength: 60,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nom du groupe',
                    hintText: 'Projet BDD — équipe 2',
                    prefixIcon: Icon(Icons.diversity_3_outlined),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Donne un nom au groupe.'
                      : null,
                ),
                const SizedBox(height: 8),
                ProtoFormLabel(
                  'Devoir',
                  trailing: homework == null
                      ? null
                      : TextButton(
                          onPressed: () => setState(() => _homeworkId = null),
                          child: const Text('Retirer'),
                        ),
                ),
                ProtoPickerField(
                  keyValue: 'group-homework-picker',
                  icon: Icons.assignment_outlined,
                  label: 'Lié au devoir (optionnel)',
                  value: homework?.title ?? 'Aucun devoir',
                  onTap: () => _pickHomework(choices.homework),
                ),
                const SizedBox(height: 16),
                ProtoFormLabel(
                  'Cours',
                  trailing: subject == null
                      ? null
                      : TextButton(
                          onPressed: () => setState(() => _subjectId = null),
                          child: const Text('Retirer'),
                        ),
                ),
                ProtoPickerField(
                  keyValue: 'group-subject-picker',
                  icon: Icons.class_outlined,
                  label: 'Lié au cours (optionnel)',
                  value:
                      subject?.name ??
                      (homework?.subjectName == null
                          ? 'Aucun cours'
                          : '${homework!.subjectName} (celui du devoir)'),
                  onTap: () => _pickSubject(choices.subjects),
                ),
                const SizedBox(height: 16),
                const ProtoFormLabel('Rendu'),
                if (homework != null)
                  ProtoCard(
                    margin: EdgeInsets.zero,
                    backgroundColor: context.sfSoftCard,
                    child: Row(
                      children: [
                        Icon(Icons.event_outlined, color: context.sfMuted),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Le ${StudyFlowFormat.longDay(homework.deadline.toLocal()).toLowerCase()}, '
                            'date du devoir',
                            style: TextStyle(
                              color: context.sfText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ProtoPickerField(
                    keyValue: 'group-due-picker',
                    icon: Icons.event_outlined,
                    label: 'Date de rendu (optionnel)',
                    value: _dueAt == null
                        ? 'Pas de date'
                        : StudyFlowFormat.longDay(_dueAt!),
                    onTap: _pickDueDate,
                  ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Objectif (optionnel)',
                    hintText: 'Consignes, livrables, format de la soutenance…',
                    alignLabelWithHint: true,
                  ),
                ),
                if (!_isEditing) ...[
                  const SizedBox(height: 8),
                  ProtoFormLabel(
                    'Inviter',
                    trailing: TextButton.icon(
                      key: const ValueKey('group-invite-button'),
                      onPressed: _pickInvitees,
                      icon: const Icon(Icons.person_add_alt, size: 18),
                      label: const Text('Choisir'),
                    ),
                  ),
                  if (_invitees.isEmpty)
                    const ProtoMutedText(
                      'Tu pourras aussi inviter plus tard. Chacun accepte '
                      'l’invitation avant de voir le groupe.',
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final classmate in _invitees)
                          InputChip(
                            avatar: GroupAvatar(
                              initials: initialsOf(classmate.name),
                              size: 24,
                            ),
                            label: Text(classmate.name),
                            onDeleted: () => setState(
                              () => _invitees = _invitees
                                  .where((x) => x.userId != classmate.userId)
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: FilledButton(
          key: const ValueKey('group-save-button'),
          onPressed: _saving ? null : _save,
          child: Text(
            _saving
                ? 'Enregistrement…'
                : _isEditing
                ? 'Enregistrer'
                : 'Créer le groupe',
          ),
        ),
      ),
    );
  }

  Future<void> _pickHomework(List<HomeworkItem> homework) async {
    final picked = await showModalBottomSheet<HomeworkItem>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _PickerSheet<HomeworkItem>(
        title: 'Lier à un devoir',
        empty: 'Aucun devoir à venir dans l’agenda de la classe.',
        items: homework,
        label: (x) => x.title,
        subtitle: (x) => [
          ?x.subjectName,
          StudyFlowFormat.shortDay(x.deadline.toLocal()),
        ].join(' · '),
        badge: (x) => x.isGroupWork ? 'Travail de groupe' : null,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _homeworkId = picked.id;
      _dueAt = picked.deadline.toLocal();
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = picked.title;
      }
    });
  }

  Future<void> _pickSubject(List<ClassSubject> subjects) async {
    final picked = await showModalBottomSheet<ClassSubject>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _PickerSheet<ClassSubject>(
        title: 'Lier à un cours',
        empty: 'Aucune matière dans la classe.',
        items: subjects,
        label: (x) => x.name,
      ),
    );
    if (picked != null && mounted) setState(() => _subjectId = picked.id);
  }

  Future<void> _pickDueDate() async {
    final picked = await StudyFlowPickers.pickDate(
      context,
      initialDate: _dueAt ?? DateTime.now().add(const Duration(days: 14)),
      firstDate: DateUtils.dateOnly(DateTime.now()),
      helpText: 'Date de rendu',
    );
    if (picked != null && mounted) {
      setState(
        () => _dueAt = DateTime(picked.year, picked.month, picked.day, 23, 59),
      );
    }
  }

  Future<void> _pickInvitees() async {
    final picked = await InviteClassmatesSheet.show(
      context,
      homeworkId: _homeworkId,
      alreadySelected: _invitees.map((x) => x.userId).toSet(),
    );
    if (picked != null && mounted) setState(() => _invitees = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final appScope = AppScope.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });

    final draft = StudyGroupDraft(
      name: _nameController.text,
      description: _descriptionController.text,
      subjectId: _subjectId,
      homeworkId: _homeworkId,
      dueAt: _homeworkId == null ? _dueAt : null,
      inviteeIds: _invitees.map((x) => x.userId).toList(),
    );

    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      final group = widget.group;
      final saved = group == null
          ? await appScope.groupRepository.createGroup(
              draft: draft,
              accessToken: accessToken,
            )
          : await appScope.groupRepository.updateGroup(
              groupId: group.summary.id,
              draft: draft,
              accessToken: accessToken,
            );
      navigator.pop(saved);
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

class _Choices {
  const _Choices({required this.homework, required this.subjects});

  final List<HomeworkItem> homework;
  final List<ClassSubject> subjects;
}

class _PickerSheet<T> extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.empty,
    required this.items,
    required this.label,
    this.subtitle,
    this.badge,
  });

  final String title;
  final String empty;
  final List<T> items;
  final String Function(T) label;
  final String Function(T)? subtitle;
  final String? Function(T)? badge;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: ProtoSectionHeading(title: title),
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: ProtoMutedText(empty),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final item in items)
                      ListTile(
                        title: Text(
                          label(item),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: subtitle == null
                            ? null
                            : Text(subtitle!(item), maxLines: 1),
                        trailing: switch (badge?.call(item)) {
                          final text? => ProtoChip(
                            label: text,
                            backgroundColor: context.sfGroupSoft,
                            foregroundColor: context.sfGroup,
                          ),
                          null => null,
                        },
                        onTap: () => Navigator.pop(context, item),
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
