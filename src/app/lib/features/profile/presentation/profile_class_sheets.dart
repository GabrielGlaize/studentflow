part of 'profile_page.dart';

class _CreateClassForCurrentUserSheet extends StatefulWidget {
  const _CreateClassForCurrentUserSheet();

  @override
  State<_CreateClassForCurrentUserSheet> createState() =>
      _CreateClassForCurrentUserSheetState();
}

class _CreateClassForCurrentUserSheetState
    extends State<_CreateClassForCurrentUserSheet> {
  final _formKey = GlobalKey<FormState>();
  final _classNameController = TextEditingController(text: 'BTS SIO 1');
  final _schoolYearController = TextEditingController(text: '2026-2027');
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
            const Row(
              children: [
                ProtoIconBox(icon: Icons.add_home_work_outlined),
                SizedBox(width: 12),
                Expanded(
                  child: ProtoSectionHeading(
                    overline: 'Classe',
                    title: 'Créer ma classe',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const ProtoMutedText(
              'À utiliser si tu as créé ton compte sans classe. Tu deviendras automatiquement délégué et un code sera généré.',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _classNameController,
              decoration: const InputDecoration(
                labelText: 'Nom de la classe',
                prefixIcon: Icon(Icons.groups_outlined),
              ),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _schoolYearController,
              decoration: const InputDecoration(
                labelText: 'Année scolaire',
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
              validator: _required,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 14),
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
                    child: Text(_isSaving ? 'Création...' : 'Créer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) {
    return (value ?? '').trim().isEmpty ? 'Champ obligatoire.' : null;
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
      final session = await appScope.classManagementRepository.createClass(
        schoolClassName: _classNameController.text,
        schoolYear: _schoolYearController.text,
        accessToken: accessToken,
      );
      await appScope.sessionController.replaceSession(session);
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _schoolYearController.dispose();
    super.dispose();
  }
}

class _JoinClassSheet extends StatefulWidget {
  const _JoinClassSheet();

  @override
  State<_JoinClassSheet> createState() => _JoinClassSheetState();
}

class _JoinClassSheetState extends State<_JoinClassSheet> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
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
            const Row(
              children: [
                ProtoIconBox(icon: Icons.key_outlined),
                SizedBox(width: 12),
                Expanded(
                  child: ProtoSectionHeading(
                    overline: 'Classe',
                    title: 'Rejoindre avec un code',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const ProtoMutedText(
              'La demande reste en attente : tu ne vois aucune donnée scolaire tant qu’un délégué ne t’a pas approuvé.',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              inputFormatters: const [GroupedCodeFormatter()],
              decoration: const InputDecoration(
                labelText: 'Code de classe',
                prefixIcon: Icon(Icons.password_outlined),
              ),
              validator: (value) {
                final code = (value ?? '').replaceAll('-', '').trim();
                if (code.isEmpty) return 'Entre le code de classe.';
                return code.length == 8
                    ? null
                    : 'Le code fait 8 caractères (ex. ABCD-EFGH).';
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 14),
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
                    child: Text(_isSaving ? 'Envoi...' : 'Envoyer'),
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
      await appScope.classManagementRepository.requestToJoinClass(
        code: _codeController.text,
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
    _codeController.dispose();
    super.dispose();
  }
}

class _ClassEditSheet extends StatefulWidget {
  const _ClassEditSheet({required this.currentClass});

  final CurrentClassInfo currentClass;

  @override
  State<_ClassEditSheet> createState() => _ClassEditSheetState();
}

class _ClassEditSheetState extends State<_ClassEditSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _schoolYearController = TextEditingController();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.currentClass.name;
    _schoolYearController.text = widget.currentClass.schoolYear;
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                ProtoIconBox(icon: Icons.school_outlined),
                SizedBox(width: 12),
                Expanded(
                  child: ProtoSectionHeading(
                    overline: 'Délégué',
                    title: 'Modifier la classe',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom de la classe',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _schoolYearController,
              decoration: const InputDecoration(
                labelText: 'Année scolaire',
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
              validator: _required,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 14),
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
    );
  }

  String? _required(String? value) {
    return (value ?? '').trim().isEmpty ? 'Champ obligatoire.' : null;
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
      await appScope.classManagementRepository.updateCurrentClass(
        name: _nameController.text,
        schoolYear: _schoolYearController.text,
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
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _schoolYearController.dispose();
    super.dispose();
  }
}
