import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/features/classes/domain/class_resource_models.dart';

/// Liste commune des matières et des intervenants de la classe.
///
/// Une matière peut avoir plusieurs intervenants et un intervenant plusieurs
/// matières : on coche les liens dans l'un ou l'autre formulaire, et le
/// formulaire de cours ne propose ensuite que les intervenants de la matière.
class ClassResourcesPage extends StatefulWidget {
  const ClassResourcesPage({required this.isDelegate, super.key});

  final bool isDelegate;

  @override
  State<ClassResourcesPage> createState() => _ClassResourcesPageState();
}

class _ClassResourcesPageState extends State<ClassResourcesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  )..addListener(() => setState(() {}));
  Future<ClassResources>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= ClassResources.load(context);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ClassResources>(
      future: _future,
      builder: (context, snapshot) {
        final resources = snapshot.data;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Matières et intervenants'),
            bottom: TabBar(
              controller: _tabController,
              labelStyle: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelColor: context.sfMuted,
              labelColor: context.sfText,
              indicatorColor: context.sfAccent,
              tabs: [
                Tab(text: 'Matières (${resources?.subjects.length ?? '…'})'),
                Tab(
                  text: 'Intervenants (${resources?.teachers.length ?? '…'})',
                ),
              ],
            ),
          ),
          floatingActionButton: widget.isDelegate && resources != null
              ? FloatingActionButton.extended(
                  key: const ValueKey('add-resource-button'),
                  backgroundColor: context.sfAccent,
                  foregroundColor: context.sfOnAccent,
                  onPressed: () => _tabController.index == 0
                      ? _editSubject(resources)
                      : _editTeacher(resources),
                  icon: const Icon(Icons.add),
                  label: Text(
                    _tabController.index == 0
                        ? 'Ajouter une matière'
                        : 'Ajouter un intervenant',
                  ),
                )
              : null,
          body: switch (snapshot.connectionState) {
            ConnectionState.done when snapshot.hasError => ProtoStateCard(
              icon: Icons.cloud_off_outlined,
              title: 'Listes indisponibles',
              message: 'Impossible de charger les matières et intervenants.',
              actionLabel: 'Réessayer',
              onAction: _reload,
            ),
            ConnectionState.done => TabBarView(
              controller: _tabController,
              children: [
                _SubjectList(
                  resources: resources!,
                  isDelegate: widget.isDelegate,
                  onEdit: (subject) => _editSubject(resources, subject),
                ),
                _TeacherList(
                  resources: resources,
                  isDelegate: widget.isDelegate,
                  onEdit: (teacher) => _editTeacher(resources, teacher),
                ),
              ],
            ),
            _ => const ProtoPageLoader(label: 'Matières et intervenants'),
          },
        );
      },
    );
  }

  void _reload() {
    setState(() => _future = ClassResources.load(context));
  }

  Future<void> _editSubject(
    ClassResources resources, [
    ClassSubject? subject,
  ]) async {
    final changed = await showSubjectFormSheet(
      context,
      resources: resources,
      subject: subject,
    );
    if (changed != null && mounted) _reload();
  }

  Future<void> _editTeacher(
    ClassResources resources, [
    ClassTeacher? teacher,
  ]) async {
    final changed = await showTeacherFormSheet(
      context,
      resources: resources,
      teacher: teacher,
    );
    if (changed != null && mounted) _reload();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

/// Matières et intervenants actifs de la classe, chargés ensemble pour
/// afficher les liens des deux côtés.
class ClassResources {
  const ClassResources({required this.subjects, required this.teachers});

  final List<ClassSubject> subjects;
  final List<ClassTeacher> teachers;

  static Future<ClassResources> load(BuildContext context) async {
    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    final subjects = appScope.classResourceRepository.listSubjects(
      accessToken: accessToken,
    );
    final teachers = appScope.classResourceRepository.listTeachers(
      accessToken: accessToken,
    );

    return ClassResources(
      subjects: (await subjects).where((x) => x.isActive).toList(),
      teachers: (await teachers).where((x) => x.isActive).toList(),
    );
  }

  ClassSubject? subjectById(String? id) {
    for (final subject in subjects) {
      if (subject.id == id) return subject;
    }
    return null;
  }

  ClassTeacher? teacherById(String? id) {
    for (final teacher in teachers) {
      if (teacher.id == id) return teacher;
    }
    return null;
  }

  /// Intervenants d'une matière, que le lien ait été coché côté matière ou
  /// côté intervenant.
  List<ClassTeacher> teachersOf(String subjectId) {
    final subject = subjectById(subjectId);
    return teachers
        .where(
          (teacher) =>
              teacher.subjectIds.contains(subjectId) ||
              (subject?.teacherIds.contains(teacher.id) ?? false),
        )
        .toList(growable: false);
  }

  List<ClassSubject> subjectsOf(String teacherId) {
    final teacher = teacherById(teacherId);
    return subjects
        .where(
          (subject) =>
              subject.teacherIds.contains(teacherId) ||
              (teacher?.subjectIds.contains(subject.id) ?? false),
        )
        .toList(growable: false);
  }
}

class _SubjectList extends StatelessWidget {
  const _SubjectList({
    required this.resources,
    required this.isDelegate,
    required this.onEdit,
  });

  final ClassResources resources;
  final bool isDelegate;
  final ValueChanged<ClassSubject> onEdit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        _ListIntro(
          isDelegate: isDelegate,
          text: isDelegate
              ? 'Ajoute les matières de la classe, puis rattache leurs intervenants. Touche une matière pour la modifier.'
              : 'Matières de la classe et leurs intervenants. Seuls les délégués peuvent modifier cette liste.',
        ),
        if (resources.subjects.isEmpty)
          ProtoStateCard(
            icon: Icons.menu_book_outlined,
            title: 'Aucune matière',
            message: isDelegate
                ? 'Commence par ajouter les matières : elles seront proposées à chaque nouveau cours.'
                : 'Ton délégué n’a pas encore ajouté de matière.',
            compact: true,
          )
        else
          ...resources.subjects.map((subject) {
            final teachers = resources.teachersOf(subject.id);
            return _ResourceTile(
              icon: Icons.menu_book_outlined,
              iconColor: context.sfShared,
              title: subject.name,
              linkedLabels: teachers.map((x) => x.displayName).toList(),
              emptyLinkLabel: 'Aucun intervenant rattaché',
              onTap: isDelegate ? () => onEdit(subject) : null,
            );
          }),
      ],
    );
  }
}

class _TeacherList extends StatelessWidget {
  const _TeacherList({
    required this.resources,
    required this.isDelegate,
    required this.onEdit,
  });

  final ClassResources resources;
  final bool isDelegate;
  final ValueChanged<ClassTeacher> onEdit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        _ListIntro(
          isDelegate: isDelegate,
          text: isDelegate
              ? 'Un intervenant peut enseigner plusieurs matières : coche-les dans sa fiche.'
              : 'Intervenants de la classe et matières qu’ils enseignent.',
        ),
        if (resources.teachers.isEmpty)
          ProtoStateCard(
            icon: Icons.badge_outlined,
            title: 'Aucun intervenant',
            message: isDelegate
                ? 'Ajoute les intervenants et coche les matières qu’ils enseignent.'
                : 'Ton délégué n’a pas encore ajouté d’intervenant.',
            compact: true,
          )
        else
          ...resources.teachers.map((teacher) {
            final subjects = resources.subjectsOf(teacher.id);
            return _ResourceTile(
              icon: Icons.badge_outlined,
              iconColor: context.sfPersonal,
              title: teacher.displayName,
              subtitle: teacher.information,
              linkedLabels: subjects.map((x) => x.name).toList(),
              emptyLinkLabel: 'Aucune matière rattachée',
              onTap: isDelegate ? () => onEdit(teacher) : null,
            );
          }),
      ],
    );
  }
}

class _ListIntro extends StatelessWidget {
  const _ListIntro({required this.isDelegate, required this.text});

  final bool isDelegate;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isDelegate ? Icons.info_outline : Icons.visibility_outlined,
            size: 18,
            color: context.sfMuted,
          ),
          const SizedBox(width: 8),
          Expanded(child: ProtoMutedText(text)),
        ],
      ),
    );
  }
}

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.linkedLabels,
    required this.emptyLinkLabel,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final List<String> linkedLabels;
  final String emptyLinkLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ProtoCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProtoIconBox(
            icon: icon,
            backgroundColor: iconColor.withValues(alpha: 0.12),
            foregroundColor: iconColor,
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
                if (subtitle case final text? when text.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  ProtoMutedText(text, maxLines: 2),
                ],
                const SizedBox(height: 8),
                if (linkedLabels.isEmpty)
                  Text(
                    emptyLinkLabel,
                    style: TextStyle(
                      color: context.sfMuted,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: linkedLabels
                        .map(
                          (label) => ProtoChip(
                            label: label,
                            backgroundColor: context.sfSoftCard,
                            foregroundColor: context.sfText,
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
          if (onTap != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Icon(Icons.chevron_right, color: context.sfChevron),
            ),
        ],
      ),
    );
  }
}

/// Ouvre la fiche d'une matière (création si [subject] est nul).
/// Renvoie la matière enregistrée, `false` si elle a été retirée, `null` si
/// rien n'a changé.
Future<Object?> showSubjectFormSheet(
  BuildContext context, {
  required ClassResources resources,
  ClassSubject? subject,
}) {
  return showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) =>
        _SubjectFormSheet(resources: resources, subject: subject),
  );
}

/// Ouvre la fiche d'un intervenant. [initialSubjectIds] pré-coche des
/// matières (par exemple celle du cours en cours de saisie).
Future<Object?> showTeacherFormSheet(
  BuildContext context, {
  required ClassResources resources,
  ClassTeacher? teacher,
  List<String> initialSubjectIds = const [],
}) {
  return showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _TeacherFormSheet(
      resources: resources,
      teacher: teacher,
      initialSubjectIds: initialSubjectIds,
    ),
  );
}

class _SubjectFormSheet extends StatefulWidget {
  const _SubjectFormSheet({required this.resources, this.subject});

  final ClassResources resources;
  final ClassSubject? subject;

  @override
  State<_SubjectFormSheet> createState() => _SubjectFormSheetState();
}

class _SubjectFormSheetState extends State<_SubjectFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController = TextEditingController(
    text: widget.subject?.name ?? '',
  );
  late final Set<String> _teacherIds = {
    if (widget.subject case final subject?)
      ...widget.resources.teachersOf(subject.id).map((x) => x.id),
  };
  bool _isSaving = false;
  String? _error;

  bool get _isEditing => widget.subject != null;

  @override
  Widget build(BuildContext context) {
    return _ResourceSheetScaffold(
      title: _isEditing ? 'Modifier la matière' : 'Nouvelle matière',
      isSaving: _isSaving,
      error: _error,
      onSubmit: _save,
      onDelete: _isEditing ? _delete : null,
      deleteLabel: 'Retirer la matière',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const ValueKey('subject-name-field'),
              controller: _nameController,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Nom de la matière',
                hintText: 'Mathématiques',
                prefixIcon: Icon(Icons.menu_book_outlined),
              ),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Entre le nom de la matière.'
                  : null,
            ),
            const SizedBox(height: 18),
            ProtoFormLabel('Intervenants de cette matière'),
            if (widget.resources.teachers.isEmpty)
              const ProtoMutedText(
                'Aucun intervenant pour l’instant. Tu pourras les rattacher depuis l’onglet Intervenants.',
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.resources.teachers
                    .map(
                      (teacher) => FilterChip(
                        label: Text(teacher.displayName),
                        selected: _teacherIds.contains(teacher.id),
                        onSelected: (selected) {
                          FocusManager.instance.primaryFocus?.unfocus();
                          setState(() {
                            selected
                                ? _teacherIds.add(teacher.id)
                                : _teacherIds.remove(teacher.id);
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });

    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      final repository = appScope.classResourceRepository;
      final subject = widget.subject;
      final saved = subject == null
          ? await repository.createSubject(
              name: _nameController.text,
              teacherIds: _teacherIds.toList(),
              accessToken: accessToken,
            )
          : await repository.updateSubject(
              subjectId: subject.id,
              name: _nameController.text,
              teacherIds: _teacherIds.toList(),
              accessToken: accessToken,
            );
      if (mounted) Navigator.pop(context, saved);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = _readable(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final subject = widget.subject!;
    final confirmed = await _confirmRemoval(
      context,
      title: 'Retirer « ${subject.name} » ?',
      message:
          'Elle ne sera plus proposée pour les nouveaux cours. Les cours déjà saisis la gardent. Tu pourras la recréer plus tard.',
    );
    if (!confirmed || !mounted) return;

    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      await appScope.classResourceRepository.deleteSubject(
        subjectId: subject.id,
        accessToken: accessToken,
      );
      if (mounted) Navigator.pop(context, false);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = _readable(error));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}

class _TeacherFormSheet extends StatefulWidget {
  const _TeacherFormSheet({
    required this.resources,
    required this.initialSubjectIds,
    this.teacher,
  });

  final ClassResources resources;
  final ClassTeacher? teacher;
  final List<String> initialSubjectIds;

  @override
  State<_TeacherFormSheet> createState() => _TeacherFormSheetState();
}

class _TeacherFormSheetState extends State<_TeacherFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TeacherName _initialName =
      widget.teacher?.name ??
      const TeacherName(civility: TeacherCivility.monsieur, lastName: '');
  late TeacherCivility _civility = _initialName.civility;
  late final TextEditingController _nameController = TextEditingController(
    text: _initialName.lastName,
  )..addListener(() => setState(() {}));
  late final TextEditingController _infoController = TextEditingController(
    text: widget.teacher?.information ?? '',
  );
  late final Set<String> _subjectIds = {
    ...widget.initialSubjectIds,
    if (widget.teacher case final teacher?)
      ...widget.resources.subjectsOf(teacher.id).map((x) => x.id),
  };
  bool _isSaving = false;
  String? _error;

  bool get _isEditing => widget.teacher != null;

  TeacherName get _name =>
      TeacherName(civility: _civility, lastName: _nameController.text);

  @override
  Widget build(BuildContext context) {
    final preview = _name.displayName;

    return _ResourceSheetScaffold(
      title: _isEditing ? 'Modifier l’intervenant' : 'Nouvel intervenant',
      isSaving: _isSaving,
      error: _error,
      onSubmit: _save,
      onDelete: _isEditing ? _delete : null,
      deleteLabel: 'Retirer l’intervenant',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<TeacherCivility>(
              segments: const [
                ButtonSegment(
                  value: TeacherCivility.monsieur,
                  label: Text('M.'),
                ),
                ButtonSegment(
                  value: TeacherCivility.madame,
                  label: Text('Mme'),
                ),
                ButtonSegment(
                  value: TeacherCivility.none,
                  label: Text('Aucune'),
                ),
              ],
              selected: {_civility},
              showSelectedIcon: false,
              onSelectionChanged: (value) {
                setState(() => _civility = value.first);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('teacher-name-field'),
              controller: _nameController,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Nom de l’intervenant',
                hintText: 'Dupont',
                prefixIcon: const Icon(Icons.badge_outlined),
                helperText: _nameController.text.trim().isEmpty
                    ? 'Il sera affiché « M. Dupont » dans les cours.'
                    : 'Affiché « $preview » dans les cours.',
              ),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Entre le nom de l’intervenant.'
                  : null,
            ),
            const SizedBox(height: 18),
            ProtoFormLabel('Matières enseignées'),
            if (widget.resources.subjects.isEmpty)
              const ProtoMutedText(
                'Ajoute d’abord les matières de la classe pour les rattacher ici.',
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.resources.subjects
                    .map(
                      (subject) => FilterChip(
                        label: Text(subject.name),
                        selected: _subjectIds.contains(subject.id),
                        onSelected: (selected) {
                          FocusManager.instance.primaryFocus?.unfocus();
                          setState(() {
                            selected
                                ? _subjectIds.add(subject.id)
                                : _subjectIds.remove(subject.id);
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _infoController,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note (optionnel)',
                hintText: 'Joignable par mail, bureau B12…',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });

    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      final repository = appScope.classResourceRepository;
      final teacher = widget.teacher;
      final saved = teacher == null
          ? await repository.createTeacher(
              displayName: _name.displayName,
              information: _infoController.text,
              subjectIds: _subjectIds.toList(),
              accessToken: accessToken,
            )
          : await repository.updateTeacher(
              teacherId: teacher.id,
              displayName: _name.displayName,
              information: _infoController.text,
              subjectIds: _subjectIds.toList(),
              accessToken: accessToken,
            );
      if (mounted) Navigator.pop(context, saved);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = _readable(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final teacher = widget.teacher!;
    final confirmed = await _confirmRemoval(
      context,
      title: 'Retirer « ${teacher.displayName} » ?',
      message:
          'Il ne sera plus proposé pour les nouveaux cours. Les cours déjà saisis le gardent. Tu pourras le recréer plus tard.',
    );
    if (!confirmed || !mounted) return;

    final appScope = AppScope.of(context);
    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      await appScope.classResourceRepository.deleteTeacher(
        teacherId: teacher.id,
        accessToken: accessToken,
      );
      if (mounted) Navigator.pop(context, false);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = _readable(error));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _infoController.dispose();
    super.dispose();
  }
}

class _ResourceSheetScaffold extends StatelessWidget {
  const _ResourceSheetScaffold({
    required this.title,
    required this.isSaving,
    required this.onSubmit,
    required this.child,
    required this.deleteLabel,
    this.onDelete,
    this.error,
  });

  final String title;
  final bool isSaving;
  final VoidCallback onSubmit;
  final VoidCallback? onDelete;
  final String deleteLabel;
  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                color: context.sfText,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            child,
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey('resource-save-button'),
              onPressed: isSaving ? null : onSubmit,
              child: Text(isSaving ? 'Enregistrement…' : 'Enregistrer'),
            ),
            if (onDelete != null) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: isSaving ? null : onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(deleteLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirmRemoval(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final confirmed = await showDialog<bool>(
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
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Retirer'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

String _readable(Object error) {
  final text = error.toString();
  return text.startsWith('Bad state: ') ? text.substring(11) : text;
}
