part of 'profile_page.dart';

class _ClassManagementSection extends StatefulWidget {
  const _ClassManagementSection({required this.isDelegate});

  final bool isDelegate;

  @override
  State<_ClassManagementSection> createState() =>
      _ClassManagementSectionState();
}

class _ClassManagementSectionState extends State<_ClassManagementSection> {
  Future<_ClassManagementState>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ClassManagementState>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ProtoCard(
            child: ProtoStateCard(
              icon: Icons.school_outlined,
              title: 'Classe',
              message: 'Chargement de ta classe et des droits délégué.',
              compact: true,
            ),
          );
        }

        final state = snapshot.data;
        if (state?.currentClass == null) {
          return ProtoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ProtoStateCard(
                  icon: Icons.school_outlined,
                  title: 'Pas encore de classe',
                  message:
                      'Tu peux continuer à gérer ton alternance, ou demander à rejoindre une classe avec un code.',
                  compact: true,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openJoinClassSheet,
                  icon: const Icon(Icons.key_outlined),
                  label: const Text('Rejoindre une classe'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _openCreateClassSheet,
                  icon: const Icon(Icons.add_home_work_outlined),
                  label: const Text('Créer ma classe'),
                ),
              ],
            ),
          );
        }

        final currentClass = state!.currentClass!;
        final isDelegate = widget.isDelegate || currentClass.isDelegate;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SettingsGroupTitle(
              title: isDelegate ? 'Gestion de classe' : 'Ma classe',
            ),
            if (isDelegate)
              ProtoGradientCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ProtoOverline(
                            'Code classe',
                            color: Colors.white70,
                          ),
                        ),
                        ProtoChip(
                          label: 'DÉLÉGUÉ',
                          backgroundColor: AppColors.mint,
                          foregroundColor: AppColors.petrol,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      'Code classe : ${currentClass.accessCode ?? 'AUCUN'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${currentClass.name} · ${currentClass.schoolYear}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'À partager seulement aux élèves de la classe. Le délégué approuve ensuite les demandes.',
                      style: TextStyle(
                        color: Color(0xDFFFFFFF),
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                          onPressed: currentClass.accessCode == null
                              ? null
                              : () => _copyAccessCode(currentClass.accessCode!),
                          icon: const Icon(Icons.copy_outlined, size: 16),
                          label: const Text('Copier'),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                          onPressed: () => _openClassEditSheet(currentClass),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Modifier'),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                          onPressed: _regenerateAccessCode,
                          icon: const Icon(Icons.refresh_outlined, size: 16),
                          label: const Text('Nouveau code'),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              ProtoCard(
                child: ProtoStateCard(
                  icon: Icons.groups_outlined,
                  title: currentClass.name,
                  message:
                      '${currentClass.schoolYear} · Tu peux consulter les membres de ta classe.',
                  compact: true,
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _leaveClass,
                icon: const Icon(Icons.exit_to_app_outlined, size: 17),
                label: const Text('Quitter la classe'),
              ),
            ),
            if (isDelegate)
              ProtoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ProtoSectionHeading(
                      overline: 'Délégué',
                      title: 'Demandes à approuver',
                    ),
                    const SizedBox(height: 10),
                    if (state.pendingRequests.isEmpty)
                      const ProtoMutedText('Aucune demande en attente.')
                    else
                      ...state.pendingRequests.map(
                        (request) => _PendingRequestRow(
                          request: request,
                          onApprove: () => _approve(request),
                          onReject: () => _reject(request),
                        ),
                      ),
                  ],
                ),
              ),
            _ClassMembersCard(
              members: state.members,
              isDelegate: isDelegate,
              onMakeDelegate: _makeDelegate,
              onRemoveMember: _removeMember,
              onLeaveDelegateRole: _leaveDelegateRole,
            ),
            _ClassResourcesEntryCard(
              subjects: state.subjects,
              teachers: state.teachers,
              isDelegate: isDelegate,
              onOpen: () => _openResources(isDelegate: isDelegate),
            ),
            _ExamsEntryCard(
              isDelegate: isDelegate,
              onOpen: () => ExamsPage.open(context),
            ),
          ],
        );
      },
    );
  }

  Future<_ClassManagementState> _load() async {
    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    final currentClass = await appScope.classManagementRepository
        .getCurrentClass(accessToken: accessToken);
    final isDelegate = widget.isDelegate || currentClass?.isDelegate == true;
    final pendingRequestsFuture = isDelegate
        ? appScope.classManagementRepository.listPendingRequests(
            accessToken: accessToken,
          )
        : Future.value(<PendingMembershipRequest>[]);
    final membersFuture = currentClass != null
        ? appScope.classManagementRepository.listMembers(
            accessToken: accessToken,
          )
        : Future.value(<ClassMember>[]);
    final subjectsFuture = currentClass == null
        ? Future.value(<ClassSubject>[])
        : appScope.classResourceRepository.listSubjects(
            accessToken: accessToken,
          );
    final teachersFuture = currentClass == null
        ? Future.value(<ClassTeacher>[])
        : appScope.classResourceRepository.listTeachers(
            accessToken: accessToken,
          );

    return _ClassManagementState(
      currentClass: currentClass,
      pendingRequests: await pendingRequestsFuture,
      members: await membersFuture,
      subjects: await subjectsFuture,
      teachers: await teachersFuture,
    );
  }

  Future<void> _copyAccessCode(String accessCode) async {
    await Clipboard.setData(ClipboardData(text: accessCode));

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Code classe copié.')));
  }

  Future<void> _openCreateClassSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const _CreateClassForCurrentUserSheet(),
    );

    if (created == true && mounted) {
      _showSnack('Classe créée. Tu es maintenant délégué.');
      setState(() {
        _future = _load();
      });
    }
  }

  Future<void> _approve(PendingMembershipRequest request) async {
    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    await appScope.classManagementRepository.approveRequest(
      requestId: request.id,
      accessToken: accessToken,
    );

    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  Future<void> _makeDelegate(ClassMember member) async {
    final shouldConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nommer délégué ?'),
        content: Text('${member.displayName} pourra gérer la classe avec toi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Nommer'),
          ),
        ],
      ),
    );
    if (shouldConfirm != true || !mounted) return;

    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    await appScope.classManagementRepository.makeDelegate(
      memberId: member.id,
      accessToken: accessToken,
    );

    if (!mounted) return;
    _showSnack('Délégué ajouté.');
    setState(() {
      _future = _load();
    });
  }

  Future<void> _removeMember(ClassMember member) async {
    final shouldConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer cet élève ?'),
        content: Text(
          '${member.displayName} ne verra plus les données de la classe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (shouldConfirm != true || !mounted) return;

    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    await appScope.classManagementRepository.removeMember(
      memberId: member.id,
      accessToken: accessToken,
    );

    if (!mounted) return;
    _showSnack('Élève retiré de la classe.');
    setState(() {
      _future = _load();
    });
  }

  Future<void> _leaveDelegateRole() async {
    final shouldConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter le rôle délégué ?'),
        content: const Text(
          'Tu resteras élève de la classe. Un autre délégué doit déjà exister.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitter le rôle'),
          ),
        ],
      ),
    );
    if (shouldConfirm != true || !mounted) return;

    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    await appScope.classManagementRepository.leaveDelegateRole(
      accessToken: accessToken,
    );

    if (!mounted) return;
    _showSnack('Rôle délégué retiré.');
    setState(() {
      _future = _load();
    });
  }

  Future<void> _leaveClass() async {
    final shouldConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter la classe ?'),
        content: const Text(
          'Tu ne verras plus les cours, devoirs, membres et messages de cette classe. Tu pourras rejoindre une autre classe ensuite.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    if (shouldConfirm != true || !mounted) return;

    try {
      final appScope = AppScope.of(context);
      final accessToken = await appScope.sessionController.accessTokenForApi();
      final session = await appScope.classManagementRepository.leaveClass(
        accessToken: accessToken,
      );
      await appScope.sessionController.replaceSession(session);

      if (!mounted) return;
      _showSnack('Tu as quitté la classe.');
      setState(() {
        _future = _load();
      });
    } on Exception catch (error) {
      if (!mounted) return;
      _showSnack(error.toString());
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reject(PendingMembershipRequest request) async {
    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    await appScope.classManagementRepository.rejectRequest(
      requestId: request.id,
      accessToken: accessToken,
    );

    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openClassEditSheet(CurrentClassInfo currentClass) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _ClassEditSheet(currentClass: currentClass),
    );

    if (!mounted || updated != true) return;
    setState(() {
      _future = _load();
    });
  }

  Future<void> _regenerateAccessCode() async {
    final shouldRegenerate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Générer un nouveau code ?'),
        content: const Text(
          'L’ancien code ne permettra plus de rejoindre la classe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Générer'),
          ),
        ],
      ),
    );

    if (shouldRegenerate != true || !mounted) return;

    final appScope = AppScope.of(context);
    final accessToken = await appScope.sessionController.accessTokenForApi();
    await appScope.classManagementRepository.regenerateAccessCode(
      accessToken: accessToken,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Nouveau code généré.')));
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openJoinClassSheet() async {
    final requested = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const _JoinClassSheet(),
    );

    if (!mounted || requested != true) return;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Demande envoyée. Un délégué doit l’approuver.'),
        ),
      );
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openResources({required bool isDelegate}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ClassResourcesPage(isDelegate: isDelegate),
      ),
    );
    if (mounted) {
      setState(() {
        _future = _load();
      });
    }
  }
}

class _ClassManagementState {
  const _ClassManagementState({
    required this.currentClass,
    required this.pendingRequests,
    required this.members,
    required this.subjects,
    required this.teachers,
  });

  final CurrentClassInfo? currentClass;
  final List<PendingMembershipRequest> pendingRequests;
  final List<ClassMember> members;
  final List<ClassSubject> subjects;
  final List<ClassTeacher> teachers;
}
