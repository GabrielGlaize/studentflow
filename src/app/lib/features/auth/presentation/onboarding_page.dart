import 'package:flutter/material.dart';
import 'dart:async';

import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/core/widgets/password_rules.dart';
import 'package:studyflow_app/features/auth/data/auth_repository.dart';
import 'package:studyflow_app/features/auth/domain/auth_models.dart';
import 'package:studyflow_app/core/widgets/grouped_code_formatter.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.chevron_left),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.14)
                        : Colors.white,
                    foregroundColor: isDark ? Colors.white : AppColors.petrol,
                  ),
                ),
                const Spacer(),
                const ProtoChip(label: 'NOUVEAU'),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Tu veux commencer comment ?',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: isDark ? Colors.white : AppColors.petrol,
                fontWeight: FontWeight.w900,
                height: 1.08,
                letterSpacing: -1.4,
              ),
            ),
            const SizedBox(height: 9),
            const ProtoMutedText(
              'Swikko peut déjà t’aider avant même que ta classe soit prête.',
            ),
            const SizedBox(height: 20),
            _ChoiceCard(
              icon: Icons.search_outlined,
              tag: 'Élève',
              title: 'Créer mon compte',
              subtitle:
                  'Pour rejoindre une classe avec un code, ou utiliser Swikko avant la rentrée.',
              color: AppColors.green,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const RegisterWithoutClassPage(),
                ),
              ),
            ),
            _ChoiceCard(
              icon: Icons.groups_outlined,
              tag: 'Délégué',
              title: 'Créer une classe',
              subtitle:
                  'Tu deviens automatiquement délégué et tu obtiens un code à partager.',
              color: AppColors.petrol,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const CreateClassPage(),
                ),
              ),
            ),
            const ProtoCard(
              backgroundColor: Color(0xFFE7F2F6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProtoIconBox(
                    icon: Icons.info_outline,
                    backgroundColor: AppColors.petrol,
                    foregroundColor: Colors.white,
                    size: 28,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ProtoMutedText(
                      'Si tu as déjà un code, choisis “Créer mon compte” puis colle le code de classe.',
                    ),
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

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tag;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ProtoCard(
      onTap: onTap,
      borderColor: color.withValues(alpha: 0.35),
      backgroundColor: color == AppColors.green
          ? const Color(0xFFEFFBF8)
          : const Color(0xFFEEF8FD),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProtoIconBox(
            icon: icon,
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.white,
            foregroundColor: color,
            size: 55,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProtoChip(
                  label: tag,
                  backgroundColor: color.withValues(alpha: 0.14),
                  foregroundColor: color,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: context.sfText,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                ProtoMutedText(subtitle),
                const SizedBox(height: 12),
                Text(
                  'Continuer →',
                  style: TextStyle(
                    color: context.sfText,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RegisterWithoutClassPage extends StatefulWidget {
  const RegisterWithoutClassPage({super.key});

  @override
  State<RegisterWithoutClassPage> createState() =>
      _RegisterWithoutClassPageState();
}

class _RegisterWithoutClassPageState extends State<RegisterWithoutClassPage> {
  final _formKey = GlobalKey<FormState>();
  static const _prefillDevelopmentCredentials = bool.fromEnvironment(
    'STUDYFLOW_PREFILL_DEV_CREDENTIALS',
    defaultValue: false,
  );

  late final _firstNameController = TextEditingController(
    text: _prefillDevelopmentCredentials ? 'Futur' : '',
  );
  late final _lastNameController = TextEditingController(
    text: _prefillDevelopmentCredentials ? 'Eleve' : '',
  );
  late final _emailController = TextEditingController(
    text: _prefillDevelopmentCredentials ? 'futur@studyflow.dev' : '',
  );
  late final _passwordController = TextEditingController(
    text: _prefillDevelopmentCredentials ? 'Password1234!' : '',
  );
  late final _confirmPasswordController = TextEditingController(
    text: _prefillDevelopmentCredentials ? 'Password1234!' : '',
  );
  final _classCodeController = TextEditingController();
  bool _isSendingCode = false;

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).sessionController;

    return _RegisterScaffold(
      title: 'Créer mon compte',
      subtitle:
          'Si tu as un code, on envoie directement ta demande à la classe.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _AccountFields(
              firstNameController: _firstNameController,
              lastNameController: _lastNameController,
              emailController: _emailController,
              passwordController: _passwordController,
              confirmPasswordController: _confirmPasswordController,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _classCodeController,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              inputFormatters: const [GroupedCodeFormatter()],
              decoration: const InputDecoration(
                labelText: 'Code de classe optionnel',
                prefixIcon: Icon(Icons.key_outlined),
              ),
            ),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: session,
              builder: (context, _) {
                final isLoading =
                    _isSendingCode || session.status.name == 'signingIn';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (session.errorMessage != null) ...[
                      Text(
                        session.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    FilledButton(
                      onPressed: isLoading ? null : _submit,
                      child: Text(
                        _isSendingCode
                            ? 'Envoi du code…'
                            : isLoading
                            ? 'Création...'
                            : 'Créer mon compte',
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final appScope = AppScope.of(context);
    setState(() => _isSendingCode = true);
    final registered = await registerWithEmailCode(
      context,
      email: _emailController.text,
      register: (emailCode) => appScope.sessionController.register(
        email: _emailController.text,
        password: _passwordController.text,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        emailCode: emailCode,
      ),
      onCodeSent: () {
        if (mounted) setState(() => _isSendingCode = false);
      },
    );
    if (mounted) setState(() => _isSendingCode = false);

    final classCode = _classCodeController.text.trim();
    if (!registered) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            classCode.isEmpty
                ? 'Compte créé. Tu peux rejoindre une classe depuis ton profil.'
                : 'Compte créé. Envoi de la demande à la classe...',
          ),
        ),
      );

    if (classCode.isEmpty) {
      _closeOnboardingFlow();
      return;
    }

    try {
      final accessToken = await appScope.sessionController.accessTokenForApi();
      await appScope.classManagementRepository.requestToJoinClass(
        code: classCode,
        accessToken: accessToken,
      );
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Compte créé. Tu pourras réessayer le code depuis ton profil.',
            ),
          ),
        );
      _closeOnboardingFlow();
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Demande envoyée. Un délégué doit maintenant valider.'),
        ),
      );
    _closeOnboardingFlow();
  }

  void _closeOnboardingFlow() {
    if (!mounted) return;
    // Compte tout neuf : une courte présentation s'ouvre sur l'accueil.
    AppScope.of(context).settingsController.requestTutorial();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _classCodeController.dispose();
    super.dispose();
  }
}

class CreateClassPage extends StatefulWidget {
  const CreateClassPage({super.key});

  @override
  State<CreateClassPage> createState() => _CreateClassPageState();
}

class _CreateClassPageState extends State<CreateClassPage> {
  final _formKey = GlobalKey<FormState>();
  static const _prefillDevelopmentCredentials = bool.fromEnvironment(
    'STUDYFLOW_PREFILL_DEV_CREDENTIALS',
    defaultValue: false,
  );

  late final _firstNameController = TextEditingController(
    text: _prefillDevelopmentCredentials ? 'Gabriel' : '',
  );
  late final _lastNameController = TextEditingController(
    text: _prefillDevelopmentCredentials ? 'Glz' : '',
  );
  late final _emailController = TextEditingController(
    text: _prefillDevelopmentCredentials ? 'nouveau.delegue@studyflow.dev' : '',
  );
  late final _passwordController = TextEditingController(
    text: _prefillDevelopmentCredentials ? 'Password1234!' : '',
  );
  late final _confirmPasswordController = TextEditingController(
    text: _prefillDevelopmentCredentials ? 'Password1234!' : '',
  );
  bool _isSendingCode = false;
  late final _classNameController = TextEditingController(
    text: _prefillDevelopmentCredentials ? 'BTS SIO 1' : '',
  );
  late final _schoolYearController = TextEditingController(
    text: _prefillDevelopmentCredentials ? '2026-2027' : '',
  );

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).sessionController;

    return _RegisterScaffold(
      title: 'Créer une classe',
      subtitle:
          'Ton compte sera créé et tu deviendras le premier délégué de la classe.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _AccountFields(
              firstNameController: _firstNameController,
              lastNameController: _lastNameController,
              emailController: _emailController,
              passwordController: _passwordController,
              confirmPasswordController: _confirmPasswordController,
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: session,
              builder: (context, _) {
                final isLoading =
                    _isSendingCode || session.status.name == 'signingIn';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (session.errorMessage != null) ...[
                      Text(
                        session.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    FilledButton(
                      onPressed: isLoading ? null : _submit,
                      child: Text(
                        _isSendingCode
                            ? 'Envoi du code…'
                            : isLoading
                            ? 'Création...'
                            : 'Créer la classe',
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final session = AppScope.of(context).sessionController;
    setState(() => _isSendingCode = true);
    final created = await registerWithEmailCode(
      context,
      email: _emailController.text,
      register: (emailCode) => session.registerAndCreateClass(
        email: _emailController.text,
        password: _passwordController.text,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        schoolClassName: _classNameController.text,
        schoolYear: _schoolYearController.text,
        emailCode: emailCode,
      ),
      onCodeSent: () {
        if (mounted) setState(() => _isSendingCode = false);
      },
    );
    if (mounted) setState(() => _isSendingCode = false);

    if (!created || !mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Compte créé. Ta classe est prête à partager.'),
        ),
      );
    AppScope.of(context).settingsController.requestTutorial();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String? _required(String? value) {
    return (value ?? '').trim().isEmpty ? 'Champ obligatoire.' : null;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _classNameController.dispose();
    _schoolYearController.dispose();
    super.dispose();
  }
}

class _RegisterScaffold extends StatelessWidget {
  const _RegisterScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.chevron_left),
                style: IconButton.styleFrom(
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.14)
                      : Colors.white,
                  foregroundColor: isDark ? Colors.white : AppColors.petrol,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: isDark ? Colors.white : AppColors.petrol,
                fontWeight: FontWeight.w900,
                height: 1.08,
                letterSpacing: -1.4,
              ),
            ),
            const SizedBox(height: 9),
            ProtoMutedText(subtitle),
            const SizedBox(height: 18),
            ProtoCard(padding: const EdgeInsets.all(18), child: child),
          ],
        ),
      ),
    );
  }
}

class _AccountFields extends StatefulWidget {
  const _AccountFields({
    required this.firstNameController,
    required this.lastNameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
  });

  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;

  @override
  State<_AccountFields> createState() => _AccountFieldsState();
}

class _AccountFieldsState extends State<_AccountFields> {
  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    // Inscription : le gestionnaire de mots de passe propose un mot de passe
    // fort, puis l'enregistre avec l'e-mail quand le compte est créé.
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: widget.firstNameController,
                  autofillHints: const [AutofillHints.givenName],
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Prénom'),
                  validator: _required,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: widget.lastNameController,
                  autofillHints: const [AutofillHints.familyName],
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nom'),
                  validator: _required,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: widget.emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Adresse e-mail',
              helperText: 'Tu recevras un code pour la confirmer.',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) return 'Entre ton adresse e-mail.';
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                return 'Adresse e-mail invalide.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('register-password-field'),
            controller: widget.passwordController,
            obscureText: !_isPasswordVisible,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _isPasswordVisible
                    ? 'Masquer le mot de passe'
                    : 'Afficher le mot de passe',
                onPressed: () =>
                    setState(() => _isPasswordVisible = !_isPasswordVisible),
                icon: Icon(
                  _isPasswordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
            validator: PasswordRules.validate,
          ),
          const SizedBox(height: 8),
          PasswordChecklist(controller: widget.passwordController),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('register-confirm-password-field'),
            controller: widget.confirmPasswordController,
            obscureText: !_isPasswordVisible,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Confirmer le mot de passe',
              prefixIcon: Icon(Icons.lock_reset_outlined),
            ),
            validator: (value) {
              if ((value ?? '').isEmpty) return 'Retape ton mot de passe.';
              return value == widget.passwordController.text
                  ? null
                  : 'Les deux mots de passe ne sont pas identiques.';
            },
          ),
        ],
      ),
    );
  }

  String? _required(String? value) {
    return (value ?? '').trim().isEmpty ? 'Champ obligatoire.' : null;
  }
}

/// Demande le code envoyé à [email], le fait saisir, puis crée le compte avec
/// [register]. Renvoie vrai quand le compte existe.
///
/// [onCodeSent] est appelé dès que le code est parti (le bouton de la page
/// peut alors redevenir normal derrière la feuille de saisie).
Future<bool> registerWithEmailCode(
  BuildContext context, {
  required String email,
  required Future<bool> Function(String? emailCode) register,
  VoidCallback? onCodeSent,
}) async {
  final session = AppScope.of(context).sessionController;
  session.clearError();

  EmailVerificationResult verification;
  try {
    verification = await session.requestEmailVerification(email: email);
  } on AuthException catch (error) {
    // Un code vient déjà de partir (l'élève a refermé puis rouvert) : on
    // propose de le saisir plutôt que de bloquer.
    if (error.statusCode != 429) {
      if (context.mounted) _showError(context, error.message);
      return false;
    }
    verification = EmailVerificationResult(
      isRequired: true,
      message:
          'Un code t’a déjà été envoyé à ${email.trim()}. Saisis-le ci-dessous.',
    );
  } on Exception catch (error) {
    if (context.mounted) _showError(context, error.toString());
    return false;
  }

  onCodeSent?.call();
  if (!verification.isRequired) return register(null);
  if (!context.mounted) return false;

  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _EmailCodeSheet(
      email: email.trim(),
      verification: verification,
      register: register,
    ),
  );
  return created == true;
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _EmailCodeSheet extends StatefulWidget {
  const _EmailCodeSheet({
    required this.email,
    required this.verification,
    required this.register,
  });

  final String email;
  final EmailVerificationResult verification;
  final Future<bool> Function(String? emailCode) register;

  @override
  State<_EmailCodeSheet> createState() => _EmailCodeSheetState();
}

class _EmailCodeSheetState extends State<_EmailCodeSheet> {
  static const _resendDelay = 60;

  late final _codeController = TextEditingController(
    text: widget.verification.developmentCode ?? '',
  );
  late String _message = widget.verification.developmentCode == null
      ? widget.verification.message
      : '${widget.verification.message}\nCode dev pré-rempli.';
  String? _error;
  bool _isSubmitting = false;
  int _secondsBeforeResend = _resendDelay;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    _secondsBeforeResend = _resendDelay;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _secondsBeforeResend <= 1) {
        timer.cancel();
        if (mounted) setState(() => _secondsBeforeResend = 0);
        return;
      }
      setState(() => _secondsBeforeResend--);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ProtoSectionHeading(
              overline: 'Dernière étape',
              title: 'Confirme ton adresse e-mail',
            ),
            const SizedBox(height: 10),
            ProtoMutedText(_message),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('email-code-field'),
              controller: _codeController,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
              ),
              decoration: const InputDecoration(
                counterText: '',
                hintText: '000000',
              ),
              onChanged: (value) {
                // Code collé ou proposé par le clavier : on valide tout de suite.
                if (_digits(value).length == 6 && !_isSubmitting) _submit();
              },
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.pop(context, false),
                  child: const Text('Modifier l’adresse'),
                ),
                const Spacer(),
                TextButton.icon(
                  key: const ValueKey('email-code-resend'),
                  onPressed: _secondsBeforeResend > 0 || _isSubmitting
                      ? null
                      : _resend,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(
                    _secondsBeforeResend > 0
                        ? 'Renvoyer (${_secondsBeforeResend}s)'
                        : 'Renvoyer le code',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey('email-code-submit'),
              onPressed: _isSubmitting ? null : _submit,
              child: Text(_isSubmitting ? 'Création…' : 'Valider le code'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final code = _digits(_codeController.text);
    if (code.length != 6) {
      setState(() => _error = 'Le code fait 6 chiffres.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final created = await widget.register(code);
    if (!mounted) return;
    if (created) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _isSubmitting = false;
      _error =
          AppScope.of(context).sessionController.errorMessage ??
          'Impossible de créer le compte.';
    });
  }

  Future<void> _resend() async {
    setState(() => _error = null);
    try {
      final result = await AppScope.of(
        context,
      ).sessionController.requestEmailVerification(email: widget.email);
      if (!mounted) return;
      setState(() {
        _message = result.message;
        if (result.developmentCode case final code?) {
          _codeController.text = code;
        }
      });
      _startCountdown();
    } on Exception catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  String _digits(String value) => value.replaceAll(RegExp('[^0-9]'), '');

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }
}
