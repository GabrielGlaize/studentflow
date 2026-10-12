import 'package:flutter/material.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/theme/prototype_widgets.dart';
import 'package:studyflow_app/features/auth/data/dev_accounts_repository.dart';

/// Écran de connexion en développement : tous les comptes du seed, chacun avec
/// la situation qu'il permet de tester. Un geste pour se connecter.
class DevAccountsPanel extends StatefulWidget {
  const DevAccountsPanel({
    required this.repository,
    required this.onSelected,
    this.enabled = true,
    super.key,
  });

  final DevAccountsRepository repository;
  final ValueChanged<DevAccount> onSelected;
  final bool enabled;

  @override
  State<DevAccountsPanel> createState() => _DevAccountsPanelState();
}

class _DevAccountsPanelState extends State<DevAccountsPanel> {
  late Future<List<DevAccount>> _accounts = widget.repository.list();

  void _reload() {
    final accounts = widget.repository.list();
    setState(() {
      _accounts = accounts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ProtoCard(
      key: const ValueKey('dev-accounts'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      borderColor: AppColors.evaluationLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ProtoSectionHeading(
            overline: 'Développement',
            title: 'Comptes de test',
          ),
          const SizedBox(height: 4),
          const ProtoMutedText(
            'Touche un compte pour te connecter. Mot de passe commun : Password1234!',
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<DevAccount>>(
            future: _accounts,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: ProtoMutedText(
                          'API du Mac injoignable. Lance make dev, puis réessaie.',
                        ),
                      ),
                      TextButton(
                        onPressed: _reload,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                );
              }
              final accounts = snapshot.data;
              if (accounts == null) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return Column(
                children: [
                  for (final account in accounts)
                    _DevAccountTile(
                      account: account,
                      enabled: widget.enabled,
                      onTap: () => widget.onSelected(account),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DevAccountTile extends StatelessWidget {
  const _DevAccountTile({
    required this.account,
    required this.enabled,
    required this.onTap,
  });

  final DevAccount account;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (account) {
      DevAccount(isDelegate: true) => (Icons.shield_outlined, AppColors.petrol),
      DevAccount(hasClass: false) => (
        Icons.person_off_outlined,
        AppColors.rose,
      ),
      DevAccount(firstLaunch: true) => (Icons.auto_awesome, AppColors.green),
      _ => (Icons.person_outline, AppColors.shared),
    };

    return ListTile(
      key: ValueKey('dev-account-${account.email}'),
      enabled: enabled,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.14),
        foregroundColor: color,
        child: Icon(icon, size: 20),
      ),
      title: Text(
        '${account.firstName} · ${account.situation}',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      ),
      subtitle: Text(
        account.details,
        style: TextStyle(color: context.sfMuted, fontSize: 12, height: 1.3),
      ),
      trailing: const Icon(Icons.login, size: 18),
      onTap: onTap,
    );
  }
}
