import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_app/core/app_scope.dart';
import 'package:studyflow_app/core/config/app_environment.dart';
import 'package:studyflow_app/core/release_notes.dart';
import 'package:studyflow_app/features/groups/data/demo_group_repository.dart';
import 'package:studyflow_app/features/groups/data/group_realtime.dart';
import 'package:studyflow_app/features/groups/domain/group_models.dart';
import 'package:studyflow_app/features/groups/presentation/group_page.dart';
import 'package:studyflow_app/main.dart';

Future<void> _signIn(WidgetTester tester) async {
  FlutterSecureStorage.setMockInitialValues({});
  DemoGroupRepository.reset();
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    const StudyFlowApp(
      environment: AppEnvironment.dev(useDemoRepositories: true),
    ),
  );
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byType(TextFormField).at(0),
    'gabriel@studyflow.dev',
  );
  await tester.enterText(find.byType(TextFormField).at(1), 'Password1234!');
  await tester.tap(find.text('Se connecter'));
  await tester.pumpAndSettle();
}

/// Laisse passer les délais simulés du dépôt de démonstration.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.pumpAndSettle();
}

Future<void> _openDemoGroup(WidgetTester tester) async {
  final card = find.byKey(const ValueKey('group-card-group-demo-bdd'));
  await tester.scrollUntilVisible(
    card,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(card);
  await _settle(tester);
}

void main() {
  testWidgets('un groupe se retrouve depuis l’accueil et discute en direct', (
    tester,
  ) async {
    await _signIn(tester);
    await _settle(tester);

    // Accueil : le groupe en cours, avec ses messages non lus.
    final card = find.byKey(const ValueKey('group-card-group-demo-bdd'));
    await tester.scrollUntilVisible(
      card,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('group-unread-group-demo-bdd')),
      findsOneWidget,
    );
    expect(find.text('Dossier réseau'), findsOneWidget);

    await _openDemoGroup(tester);
    expect(find.byType(GroupPage), findsOneWidget);
    expect(
      find.text('On se cale un point jeudi midi pour les diapos ?'),
      findsOneWidget,
    );

    // J'écris : le message apparaît tout de suite.
    await tester.enterText(
      find.byKey(const ValueKey('group-chat-input')),
      'Ok pour jeudi midi',
    );
    await tester.tap(find.byKey(const ValueKey('group-chat-send')));
    await _settle(tester);
    expect(find.text('Ok pour jeudi midi'), findsOneWidget);

    // Le temps réel apporte « Liam écrit… », puis son message.
    final realtime =
        AppScope.of(tester.element(find.byType(GroupPage))).groupRealtime
            as LocalGroupRealtime;
    realtime.emit(const GroupTypingEvent('group-demo-bdd', 'demo-user-3'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Liam écrit…'), findsOneWidget);

    realtime.emit(
      GroupMessageEvent(
        GroupMessage(
          id: 'live-1',
          groupId: 'group-demo-bdd',
          authorId: 'demo-user-3',
          authorName: 'Liam M.',
          text: 'Parfait, je réserve la salle',
          isMine: false,
          isDeleted: false,
          createdAt: DateTime.now(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Parfait, je réserve la salle'), findsOneWidget);
    expect(find.text('Liam écrit…'), findsNothing);
  });

  testWidgets('les tâches se répartissent et avancent en un geste', (
    tester,
  ) async {
    await _signIn(tester);
    await _settle(tester);
    await _openDemoGroup(tester);

    await tester.tap(find.byKey(const ValueKey('group-tab-tasks')));
    await _settle(tester);
    expect(find.text('Script SQL de création'), findsOneWidget);
    expect(find.text('25 % fait'), findsOneWidget);

    // Le script passe de « en cours » à « fait ».
    await tester.tap(
      find.byKey(const ValueKey('group-task-toggle-task-demo-2')),
    );
    await _settle(tester);
    expect(find.text('50 % fait'), findsOneWidget);

    // Nouvelle tâche confiée à Liam.
    await tester.tap(find.byKey(const ValueKey('group-task-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('group-task-title')),
      'Relire le rapport',
    );
    await tester.tap(
      find.byKey(const ValueKey('group-task-assignee-demo-user-3')),
    );
    await tester.tap(find.byKey(const ValueKey('group-task-save')));
    await _settle(tester);
    expect(find.text('Relire le rapport'), findsOneWidget);
    expect(find.textContaining('Gabriel D., Liam M.'), findsOneWidget);
  });

  testWidgets('une réunion se propose dans un créneau commun', (tester) async {
    await _signIn(tester);
    await _settle(tester);
    await _openDemoGroup(tester);

    await tester.tap(find.byKey(const ValueKey('group-tab-planning')));
    await _settle(tester);
    expect(find.text('Créneaux communs'), findsOneWidget);
    expect(find.text('Sur place'), findsNWidgets(2));

    await tester.tap(find.text('Proposer').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('group-propose-confirm')));
    await _settle(tester);

    // Moi seul ai répondu : la réunion attend les autres.
    expect(find.text('À valider'), findsOneWidget);
    final yes = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Je suis dispo'),
    );
    expect(yes.onPressed, isNull);
    expect(find.text('Pas dispo'), findsOneWidget);
  });

  testWidgets('une invitation se rejoint depuis Mes groupes', (tester) async {
    await _signIn(tester);
    await _settle(tester);

    final all = find.byKey(const ValueKey('dashboard-groups-all'));
    await tester.scrollUntilVisible(
      all,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(all);
    await _settle(tester);
    expect(find.text('Invitations'), findsOneWidget);
    expect(find.text('Nina B. t’invite dans ce groupe privé.'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('group-accept-group-demo-reseau')),
    );
    await _settle(tester);
    expect(find.byType(GroupPage), findsOneWidget);
    expect(find.text('Gabriel D. a rejoint le groupe.'), findsOneWidget);
  });

  testWidgets('l’historique des mises à jour liste toutes les versions', (
    tester,
  ) async {
    await _signIn(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Profil'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-settings-button')));
    await tester.pumpAndSettle();

    final tile = find.byKey(const ValueKey('release-history'));
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.text(ReleaseNotes.current.title), findsOneWidget);

    // Les versions précédentes se déplient, avec leurs correctifs.
    final history = find.descendant(
      of: find.byKey(const ValueKey('release-history-list')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('StudyFlow devient Swikko'),
      300,
      scrollable: history,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('StudyFlow devient Swikko'));
    await tester.pumpAndSettle();
    expect(find.text('CORRECTIFS'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Première version'),
      300,
      scrollable: history,
    );
    expect(find.text('Première version'), findsOneWidget);
  });
}
