import 'package:flutter/material.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/features/auth/application/session_controller.dart';
import 'package:studyflow_app/features/auth/presentation/onboarding_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  static const _prefillDevelopmentCredentials = bool.fromEnvironment(
    'STUDYFLOW_PREFILL_DEV_CREDENTIALS',
    defaultValue: false,
  );

  late final _emailController = TextEditingController(
    text: _prefillDevelopmentCredentials ? 'gabriel@studyflow.dev' : '',
  );
  late final _passwordController = TextEditingController(
    text: _prefillDevelopmentCredentials ? 'Password1234!' : '',
  );

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).sessionController;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
            children: [
              const _AuthBrand(),
              const SizedBox(height: 24),
              Text(
                'Bienvenue sur StudyFlow',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: isDark ? Colors.white : AppColors.petrol,
                  fontWeight: FontWeight.w900,
                  height: 1.08,
                  letterSpacing: -1.4,
                ),
              ),
              const SizedBox(height: 9),
              const ProtoMutedText(
                'Connecte-toi pour retrouver ton tableau de bord, tes cours et tes tâches.',
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : const Color(0xFFDFE9EF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 39,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.mint : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.petrol.withValues(alpha: 0.09),
                              blurRadius: 13,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Connexion',
                          style: TextStyle(
                            color: AppColors.petrol,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _openOnboarding,
                        child: SizedBox(
                          height: 39,
                          child: Center(
                            child: Text(
                              'Créer un compte',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white70
                                    : AppColors.muted,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ProtoCard(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Adresse e-mail',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _isPasswordVisible
                                ? 'Masquer le mot de passe'
                                : 'Afficher le mot de passe',
                            onPressed: () => setState(
                              () => _isPasswordVisible = !_isPasswordVisible,
                            ),
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: _validatePassword,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showPasswordResetInfo,
                          child: const Text('Mot de passe oublié ?'),
                        ),
                      ),
                      const SizedBox(height: 18),
                      AnimatedBuilder(
                        animation: session,
                        builder: (context, _) {
                          final isLoading =
                              session.status == SessionStatus.signingIn;

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
                                const SizedBox(height: 12),
                              ],
                              FilledButton.icon(
                                onPressed: isLoading ? null : _submit,
                                icon: isLoading
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.login),
                                label: Text(
                                  isLoading ? 'Connexion...' : 'Se connecter',
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_prefillDevelopmentCredentials) ...[
                ProtoCard(
                  backgroundColor: const Color(0xFFEDF8FD),
                  borderColor: const Color(0xFFA6D9F7),
                  child: Text(
                    'Compte dev prérempli : gabriel@studyflow.dev / Password1234!.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.sfText,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                onPressed: _openOnboarding,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Créer un compte ou une classe'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    AppScope.of(context).sessionController.login(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  void _openOnboarding() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const OnboardingPage()),
    );
  }

  void _showPasswordResetInfo() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) =>
          _PasswordResetSheet(initialEmail: _emailController.text),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Entre ton adresse e-mail.';
    if (!email.contains('@')) return 'Adresse e-mail invalide.';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.trim().isEmpty) return 'Entre ton mot de passe.';
    if (password.length < 6) return 'Au moins 6 caractères.';
    return null;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class _PasswordResetSheet extends StatefulWidget {
  const _PasswordResetSheet({required this.initialEmail});

  final String initialEmail;

  @override
  State<_PasswordResetSheet> createState() => _PasswordResetSheetState();
}

class _PasswordResetSheetState extends State<_PasswordResetSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(
    text: widget.initialEmail.trim(),
  );
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _hasRequestedToken = false;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _message;
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ProtoSectionHeading(
                overline: 'Compte',
                title: 'Réinitialiser le mot de passe',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Adresse e-mail',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: _validateEmail,
              ),
              if (_hasRequestedToken) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tokenController,
                  decoration: const InputDecoration(
                    labelText: 'Code reçu',
                    prefixIcon: Icon(Icons.key_outlined),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Entre le code de réinitialisation.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Nouveau mot de passe',
                    prefixIcon: const Icon(Icons.lock_reset_outlined),
                    suffixIcon: IconButton(
                      tooltip: _isPasswordVisible
                          ? 'Masquer le mot de passe'
                          : 'Afficher le mot de passe',
                      onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible,
                      ),
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  validator: _validatePassword,
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 10),
                ProtoCard(
                  backgroundColor: const Color(0xFFEDF8FD),
                  borderColor: AppColors.sky,
                  child: Text(
                    _message!,
                    style: TextStyle(
                      color: context.sfText,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Fermer'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isLoading
                          ? null
                          : _hasRequestedToken
                          ? _resetPassword
                          : _requestToken,
                      child: Text(
                        _isLoading
                            ? 'Patiente...'
                            : _hasRequestedToken
                            ? 'Réinitialiser'
                            : 'Recevoir un code',
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

  Future<void> _requestToken() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _message = null;
    });

    try {
      final result = await AppScope.of(
        context,
      ).sessionController.requestPasswordReset(email: _emailController.text);
      if (!mounted) return;
      setState(() {
        _hasRequestedToken = true;
        if (result.developmentToken case final token?) {
          _tokenController.text = token;
        }
        _message = result.developmentToken == null
            ? result.message
            : '${result.message}\nCode dev pré-rempli : ${result.developmentToken}';
      });
    } on Exception catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AppScope.of(context).sessionController.resetPassword(
        email: _emailController.text,
        token: _tokenController.text,
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Mot de passe réinitialisé.')),
        );
      Navigator.pop(context);
    } on Exception catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Entre ton adresse e-mail.';
    if (!email.contains('@')) return 'Adresse e-mail invalide.';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.length < 10) return 'Au moins 10 caractères.';
    if (!RegExp('[A-Z]').hasMatch(password)) return 'Ajoute une majuscule.';
    if (!RegExp('[a-z]').hasMatch(password)) return 'Ajoute une minuscule.';
    if (!RegExp('[0-9]').hasMatch(password)) return 'Ajoute un chiffre.';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'Ajoute un caractère spécial.';
    }
    return null;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class _AuthBrand extends StatelessWidget {
  const _AuthBrand();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        const ProtoIconBox(
          icon: Icons.school_outlined,
          backgroundColor: AppColors.petrol,
          foregroundColor: Colors.white,
          size: 34,
        ),
        const SizedBox(width: 9),
        Text(
          'StudyFlow',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.petrol,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
