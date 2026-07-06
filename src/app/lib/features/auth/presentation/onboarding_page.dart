import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';

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
              'StudyFlow peut déjà t’aider avant même que ta classe soit prête.',
            ),
            const SizedBox(height: 20),
            _ChoiceCard(
              icon: Icons.search_outlined,
              tag: 'Élève',
              title: 'Créer mon compte',
              subtitle:
                  'Pour rejoindre une classe avec un code, ou utiliser StudyFlow avant la rentrée.',
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
                    fontSize: 9,
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
  final _classCodeController = TextEditingController();

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
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _classCodeController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: const [_UpperCaseTextFormatter()],
              decoration: const InputDecoration(
                labelText: 'Code de classe optionnel',
                prefixIcon: Icon(Icons.key_outlined),
              ),
            ),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: session,
              builder: (context, _) {
                final isLoading = session.status.name == 'signingIn';
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
                        isLoading ? 'Création...' : 'Créer mon compte',
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
    final registered = await appScope.sessionController.register(
      email: _emailController.text,
      password: _passwordController.text,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
    );

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
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
                final isLoading = session.status.name == 'signingIn';
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
                        isLoading ? 'Création...' : 'Créer la classe',
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

    final created = await AppScope.of(context).sessionController
        .registerAndCreateClass(
          email: _emailController.text,
          password: _passwordController.text,
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          schoolClassName: _classNameController.text,
          schoolYear: _schoolYearController.text,
        );

    if (!created || !mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Compte créé. Ta classe est prête à partager.'),
        ),
      );
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
    _classNameController.dispose();
    _schoolYearController.dispose();
    super.dispose();
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  const _UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
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

class _AccountFields extends StatelessWidget {
  const _AccountFields({
    required this.firstNameController,
    required this.lastNameController,
    required this.emailController,
    required this.passwordController,
  });

  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: firstNameController,
                decoration: const InputDecoration(labelText: 'Prénom'),
                validator: _required,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: lastNameController,
                decoration: const InputDecoration(labelText: 'Nom'),
                validator: _required,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Adresse e-mail',
            prefixIcon: Icon(Icons.mail_outline),
          ),
          validator: (value) {
            final email = value?.trim() ?? '';
            if (email.isEmpty) return 'Entre ton adresse e-mail.';
            if (!email.contains('@')) return 'Adresse e-mail invalide.';
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Mot de passe',
            prefixIcon: Icon(Icons.lock_outline),
          ),
          validator: (value) {
            final password = value ?? '';
            if (password.trim().isEmpty) return 'Champ obligatoire.';
            if (password.length < 6) return 'Au moins 6 caractères.';
            return null;
          },
        ),
      ],
    );
  }

  String? _required(String? value) {
    return (value ?? '').trim().isEmpty ? 'Champ obligatoire.' : null;
  }
}
