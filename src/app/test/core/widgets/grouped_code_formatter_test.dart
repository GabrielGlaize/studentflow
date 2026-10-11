import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_app/core/widgets/grouped_code_formatter.dart';
import 'package:studyflow_app/core/widgets/password_rules.dart';

void main() {
  const formatter = GroupedCodeFormatter();

  TextEditingValue type(String before, String after) =>
      formatter.formatEditUpdate(
        TextEditingValue(
          text: before,
          selection: TextSelection.collapsed(offset: before.length),
        ),
        TextEditingValue(
          text: after,
          selection: TextSelection.collapsed(offset: after.length),
        ),
      );

  test('le tiret apparaît tout seul après le 4e caractère', () {
    expect(type('ab', 'abc').text, 'ABC');
    expect(type('ABC', 'ABCd').text, 'ABCD-');
    expect(type('ABCD-', 'ABCD-e').text, 'ABCD-E');
  });

  test('un retour arrière après le tiret l’efface', () {
    final value = type('ABCD-', 'ABCD');
    expect(value.text, 'ABCD');
    expect(value.selection.baseOffset, 4);
  });

  test('un code collé est remis en forme et limité à 8 caractères', () {
    expect(type('', 'abcd efgh').text, 'ABCD-EFGH');
    expect(type('', 'ABCD-EFGH-XYZ').text, 'ABCD-EFGH');
  });

  test('les règles du mot de passe sont celles du serveur', () {
    expect(PasswordRules.validate('court'), isNotNull);
    expect(PasswordRules.validate('motdepasse123!'), contains('majuscule'));
    expect(PasswordRules.validate('Motdepasse123'), contains('spécial'));
    expect(PasswordRules.validate('Motdepasse123!'), isNull);
  });
}
