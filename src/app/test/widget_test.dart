import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_app/core/config/app_environment.dart';
import 'package:studyflow_app/main.dart';

void main() {
  testWidgets('le parcours onboarding propose compte ou classe', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(
      const StudyFlowApp(
        environment: AppEnvironment.dev(useDemoRepositories: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Créer un compte ou une classe'));
    await tester.pumpAndSettle();

    expect(find.text('Tu veux commencer comment ?'), findsOneWidget);
    expect(find.text('Créer mon compte'), findsOneWidget);
    expect(find.text('Créer une classe'), findsOneWidget);
  });

  testWidgets('la connexion ouvre le tableau de bord', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(
      const StudyFlowApp(
        environment: AppEnvironment.dev(useDemoRepositories: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bienvenue sur StudyFlow'), findsOneWidget);

    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    expect(find.text('Bonjour Gabriel'), findsOneWidget);
    expect(find.text('Flutter — navigation et état'), findsOneWidget);
    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Agenda'), findsOneWidget);
    expect(find.text('Alternance'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);

    await tester.tap(find.text('Planning'));
    await tester.pumpAndSettle();

    expect(find.text('Planning'), findsWidgets);
    expect(find.byKey(const ValueKey('add-course-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-course-button')));
    await tester.pumpAndSettle();

    expect(find.text('Ajouter un cours'), findsWidgets);
    expect(find.text('Matière'), findsOneWidget);
    expect(find.text('Professeur optionnel'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();

    expect(find.text('Agenda et tâches'), findsOneWidget);
    expect(find.text('Devoirs de classe'), findsOneWidget);
    expect(find.text('Rendre le dossier d’anglais'), findsOneWidget);

    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tâche école'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(EditableText).first,
      'Appeler une entreprise',
    );
    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -220));
    await tester.pumpAndSettle();
    expect(find.text('Appeler une entreprise'), findsOneWidget);

    await tester.tap(find.text('Appeler une entreprise'));
    await tester.pumpAndSettle();

    expect(find.text('École'), findsWidgets);
    expect(find.text('Fermer'), findsOneWidget);

    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('task-done-demo-task-2')));
    await tester.pumpAndSettle();

    expect(find.text('Appeler une entreprise'), findsNothing);

    await tester.tap(find.text('Alternance').last);
    await tester.pumpAndSettle();

    expect(find.text('Alternances'), findsWidgets);
    expect(find.text('Offres partagées par la classe'), findsOneWidget);
    expect(find.textContaining('Atelier Numérique'), findsWidgets);

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(find.text('Alternance développeur Flutter'), findsOneWidget);
    expect(find.text('Voir l’offre'), findsWidgets);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    expect(find.text('Profil et réglages'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Gestion de classe'),
      180,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 10,
    );
    await tester.pumpAndSettle();
    expect(find.text('Gestion de classe'), findsOneWidget);
    expect(find.text('Code classe : SIO1-42'), findsOneWidget);
    expect(find.text('Lina Moreau'), findsOneWidget);

    await tester.tap(find.text('Approuver'));
    await tester.pumpAndSettle();
    expect(find.text('Lina Moreau'), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('has-company-switch-line')),
      180,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 20,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const ValueKey('has-company-switch-line'))),
      alignment: 0.35,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(find.text('J’ai une entreprise'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('has-company-switch-line')));
    await tester.pumpAndSettle();

    expect(find.text('Entreprise'), findsWidgets);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Entreprise'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Entreprise'), findsWidgets);
    expect(find.text('Documents importants'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('open-company-tasks-card')),
      120,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('Tâches entreprise')),
      alignment: 0.25,
    );
    await tester.pumpAndSettle();
    expect(find.text('Tâches entreprise'), findsOneWidget);
    expect(find.text('Contacts'), findsWidgets);

    await tester.tap(find.text('Tâches entreprise'));
    await tester.pumpAndSettle();

    expect(find.text('Agenda et tâches'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Relancer une entreprise'),
      160,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 10,
    );
    await tester.pumpAndSettle();
    expect(find.text('Relancer une entreprise'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Entreprise'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-company-document-button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).at(0), 'Contrat signé');
    await tester.enterText(
      find.byType(EditableText).at(2),
      'https://drive.example/contrat',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Ajouter'));
    await tester.pumpAndSettle();

    expect(find.text('Contrat signé'), findsOneWidget);
    expect(
      find.textContaining('https://drive.example/contrat'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('add-company-contact-button')),
      120,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -140));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-company-contact-button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).at(0), 'Marie Martin');
    await tester.enterText(find.byType(EditableText).at(1), 'Tutrice');
    await tester.enterText(
      find.byType(EditableText).at(2),
      'marie@entreprise.fr',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Ajouter'));
    await tester.pumpAndSettle();

    expect(find.text('Marie Martin'), findsOneWidget);
    expect(find.text('Tutrice · marie@entreprise.fr'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Profil'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profil et réglages'), findsOneWidget);
  });
}
