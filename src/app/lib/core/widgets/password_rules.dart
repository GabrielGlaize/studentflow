import 'package:flutter/material.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';

/// Règles du serveur pour un mot de passe (Identity) : les vérifier dans l'app
/// évite d'envoyer le formulaire pour découvrir l'erreur ensuite.
abstract final class PasswordRules {
  static const minimumLength = 10;

  static final List<({String label, bool Function(String) isMet})> all = [
    (
      label: 'Au moins $minimumLength caractères',
      isMet: (value) => value.length >= minimumLength,
    ),
    (label: 'Une majuscule', isMet: (value) => RegExp('[A-Z]').hasMatch(value)),
    (label: 'Une minuscule', isMet: (value) => RegExp('[a-z]').hasMatch(value)),
    (label: 'Un chiffre', isMet: (value) => RegExp('[0-9]').hasMatch(value)),
    (
      label: 'Un caractère spécial (! ? @ # …)',
      isMet: (value) => RegExp(r'[^A-Za-z0-9]').hasMatch(value),
    ),
  ];

  /// Message d'erreur du premier critère non rempli, ou nul si tout est bon.
  static String? validate(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Choisis un mot de passe.';
    for (final rule in all) {
      if (!rule.isMet(password)) {
        return 'Mot de passe : ${rule.label.toLowerCase()} au minimum.';
      }
    }
    return null;
  }
}

/// Critères du mot de passe, cochés au fil de la frappe.
class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({required this.controller, super.key});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final rule in PasswordRules.all)
            _Criterion(label: rule.label, isMet: rule.isMet(value.text)),
        ],
      ),
    );
  }
}

class _Criterion extends StatelessWidget {
  const _Criterion({required this.label, required this.isMet});

  final String label;
  final bool isMet;

  @override
  Widget build(BuildContext context) {
    final color = isMet ? AppColors.green : context.sfMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isMet ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 15,
          color: color,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: isMet ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
