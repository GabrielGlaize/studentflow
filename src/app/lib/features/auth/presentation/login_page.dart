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
  static const _useDemoAuth = bool.fromEnvironment(
    'STUDYFLOW_USE_DEMO_AUTH',
    defaultValue: true,
  );

  late final _emailController = TextEditingController(
    text: _useDemoAuth ? 'gabriel@studyflow.dev' : '',
  );
  late final _passwordController = TextEditingController(
    text: _useDemoAuth ? 'Password123' : '',
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
                  color: const Color(0xFFDFE9EF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 39,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
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
                        child: const SizedBox(
                          height: 39,
                          child: Center(
                            child: Text(
                              'Créer un compte',
                              style: TextStyle(
                                color: AppColors.muted,
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
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        decoration: const InputDecoration(
                          labelText: 'Mot de passe',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: _validatePassword,
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
              if (_useDemoAuth) ...[
                const ProtoCard(
                  backgroundColor: Color(0xFFEDF8FD),
                  borderColor: Color(0xFFA6D9F7),
                  child: Text(
                    'Mode démo : n’importe quel e-mail valide et mot de passe non vide fonctionnent.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.petrol,
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
