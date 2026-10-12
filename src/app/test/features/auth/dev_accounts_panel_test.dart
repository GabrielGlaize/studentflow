import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_app/features/auth/data/dev_accounts_repository.dart';
import 'package:studyflow_app/features/auth/presentation/dev_accounts_panel.dart';

class _FakeDevAccounts implements DevAccountsRepository {
  _FakeDevAccounts(this.accounts);

  List<DevAccount>? accounts;

  @override
  Future<List<DevAccount>> list() async =>
      accounts ?? (throw Exception('API injoignable'));
}

const _chloe = DevAccount(
  email: 'chloe@studyflow.dev',
  password: 'Password1234!',
  firstName: 'Chloé',
  lastName: 'Durand',
  situation: 'Premier lancement',
  details: 'La présentation de l’app s’ouvre après la connexion.',
  firstLaunch: true,
);

Widget _host(
  DevAccountsRepository repository,
  ValueChanged<DevAccount> onSelected,
) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: DevAccountsPanel(repository: repository, onSelected: onSelected),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'les comptes de dev se listent avec leur situation et se choisissent',
    (tester) async {
      DevAccount? selected;
      await tester.pumpWidget(
        _host(_FakeDevAccounts([_chloe]), (account) => selected = account),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chloé · Premier lancement'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('dev-account-chloe@studyflow.dev')),
      );
      expect(selected?.firstLaunch, isTrue);
    },
  );

  testWidgets('API injoignable : un message et un bouton pour réessayer', (
    tester,
  ) async {
    final repository = _FakeDevAccounts(null);
    await tester.pumpWidget(_host(repository, (_) {}));
    await tester.pumpAndSettle();
    expect(find.textContaining('make dev'), findsOneWidget);

    repository.accounts = [_chloe];
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Chloé · Premier lancement'), findsOneWidget);
  });
}
