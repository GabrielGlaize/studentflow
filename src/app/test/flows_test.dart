import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_app/core/config/app_environment.dart';
import 'package:studyflow_app/core/widgets/date_time_pickers.dart';
import 'package:studyflow_app/features/schedule/data/demo_course_repository.dart';
import 'package:studyflow_app/features/schedule/domain/course_models.dart';
import 'package:studyflow_app/main.dart';

Future<void> _signIn(WidgetTester tester) async {
  FlutterSecureStorage.setMockInitialValues({});
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

/// Jour affiché à l'ouverture du planning (le lundi suivant le week-end).
DateTime _firstShownDay() {
  final today = DateUtils.dateOnly(DateTime.now());
  return today.weekday > DateTime.friday
      ? StudyFlowDates.addDays(StudyFlowDates.mondayOf(today), 7)
      : today;
}

DateTime _nextWeekday(DateTime day) {
  var next = StudyFlowDates.addDays(day, 1);
  while (next.weekday > DateTime.friday) {
    next = StudyFlowDates.addDays(next, 1);
  }
  return next;
}

void main() {
  testWidgets('le planning se balaie et marque la pause déjeuner', (
    tester,
  ) async {
    // Jeudi de la semaine affichée : un cours le matin, un l'après-midi.
    final thursday = StudyFlowDates.addDays(
      StudyFlowDates.mondayOf(_firstShownDay()),
      3,
    );
    const repository = DemoCourseRepository();
    // Hors de l'horloge simulée : le dépôt de démo attend de vraies durées.
    await tester.runAsync(() async {
      await repository.listCourses(from: thursday, to: thursday);
      for (final (start, end) in [('09:00', '12:00'), ('14:00', '16:00')]) {
        await repository.createCourse(
          data: CourseFormData(
            subjectId: 'subject-1',
            subjectName: 'Mathématiques',
            day: thursday,
            startsAt: start,
            endsAt: end,
            room: 'B204',
          ),
        );
      }
    });

    await _signIn(tester);
    await tester.tap(find.text('Planning'));
    await tester.pumpAndSettle();

    final shown = _firstShownDay();
    expect(
      find.text(StudyFlowFormat.longDay(shown).toUpperCase()),
      findsOneWidget,
    );
    expect(find.text('Aujourd’hui'), findsWidgets);

    // Balayage vers la gauche : jour de cours suivant.
    await tester.fling(
      find.byKey(const ValueKey('day-pager')),
      const Offset(-400, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(
      find.text(StudyFlowFormat.longDay(_nextWeekday(shown)).toUpperCase()),
      findsOneWidget,
    );

    // Retour au jour affiché au départ, puis vue semaine : le bouton parle
    // de la semaine et la pause de midi est bien visible.
    await tester.tap(find.byKey(const ValueKey('planning-today-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Semaine'));
    await tester.pumpAndSettle();
    expect(find.text('Cette semaine'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('long-break')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Pause déjeuner · 2 h'), findsOneWidget);
  });

  testWidgets('la fiche de révision des partiels se remplit et se coche', (
    tester,
  ) async {
    await _signIn(tester);

    // Partiels dans 9 jours : la carte apparaît sur l'accueil.
    expect(find.text('J-9'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('exam-countdown')));
    await tester.pumpAndSettle();

    expect(find.text('Partiels du semestre 1'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('exam-subject-exam-demo-subject-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chapitre 3 : intégrales et primitives'), findsOneWidget);
    expect(find.text('Tu as révisé 1 point sur 3'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('revision-item-field')),
      'Théorème des valeurs intermédiaires',
    );
    await tester.tap(find.byKey(const ValueKey('revision-item-send')));
    await tester.pumpAndSettle();
    expect(find.text('Théorème des valeurs intermédiaires'), findsOneWidget);

    await tester.tap(find.text('Théorème des valeurs intermédiaires'));
    await tester.pumpAndSettle();
    expect(find.text('Tu as révisé 2 points sur 4'), findsOneWidget);

    await tester.tap(find.text('Ressources (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Quiz interactif sur les intégrales'), findsOneWidget);
    expect(find.textContaining('Artefact Claude'), findsOneWidget);

    // Un lien non sécurisé est refusé avant même l'envoi.
    await tester.tap(find.byKey(const ValueKey('add-link-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('link-url-field')),
      'http://exemple.fr/cours',
    );
    await tester.tap(find.byKey(const ValueKey('link-save-button')));
    await tester.pumpAndSettle();
    expect(
      find.text('Utilise un lien sécurisé, qui commence par https://'),
      findsOneWidget,
    );
  });

  testWidgets('un délégué retire plusieurs matières d’un coup', (tester) async {
    await _signIn(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Profil'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('class-resources-entry')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // Remonte la carte en haut de l'écran, loin de la barre de navigation.
    await tester.ensureVisible(
      find.byKey(const ValueKey('class-resources-entry')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('class-resources-entry')));
    await tester.pumpAndSettle();
    expect(find.text('Matières (3)'), findsOneWidget);

    await tester.longPress(
      find.byKey(const ValueKey('subject-tile-subject-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('subject-tile-subject-3')));
    await tester.pumpAndSettle();
    expect(find.text('2 sélectionnés'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('delete-selected-resources')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retirer'));
    await tester.pumpAndSettle();

    expect(find.text('Matières (1)'), findsOneWidget);
    expect(find.text('2 retirés.'), findsOneWidget);
  });
}
