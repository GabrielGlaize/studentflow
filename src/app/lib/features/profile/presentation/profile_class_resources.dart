part of 'profile_page.dart';

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
                if (member.email case final email?) ...[
                  const SizedBox(height: 3),
                  Text(
                    email,
                    style: TextStyle(color: context.sfMuted, fontSize: 8),
                  ),
                ],
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
