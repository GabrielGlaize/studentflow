import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_app/features/exams/domain/exam_models.dart';

void main() {
  test('les liens connus sont reconnus', () {
    expect(
      RevisionLinkKind.of('https://claude.ai/public/artifacts/123'),
      RevisionLinkKind.claude,
    );
    expect(
      RevisionLinkKind.of('https://docs.google.com/document/d/1'),
      RevisionLinkKind.drive,
    );
    expect(RevisionLinkKind.of('https://youtu.be/abc'), RevisionLinkKind.video);
    expect(RevisionLinkKind.of('https://exemple.fr'), RevisionLinkKind.web);
  });

  test('seuls les liens https sans identifiants passent', () {
    expect(RevisionLinkRules.check('https://claude.ai/x'), isNull);
    expect(RevisionLinkRules.check('http://exemple.fr'), contains('https://'));
    expect(RevisionLinkRules.check('javascript:alert(1)'), isNotNull);
    expect(RevisionLinkRules.check('https://moi:mdp@exemple.fr'), isNotNull);
    expect(RevisionLinkRules.check(''), isNotNull);
  });

  test('les fichiers sont filtrés par type et par taille', () {
    expect(RevisionFileRules.check('cours.pdf', 1000), isNull);
    expect(RevisionFileRules.check('quiz.html', 1000), isNull);
    expect(RevisionFileRules.check('setup.exe', 1000), contains('.exe'));
    expect(RevisionFileRules.check('archive.zip', 1000), isNotNull);
    expect(
      RevisionFileRules.check('page.html', 3 * 1024 * 1024),
      contains('2 Mo'),
    );
    expect(RevisionFileRules.check('vide.txt', 0), isNotNull);
  });

  test('la progression des partiels suit les cases cochées', () {
    final session = ExamSession.fromJson({
      'id': 's',
      'title': 'Partiels',
      'startsOn': '2026-10-19',
      'endsOn': '2026-10-22',
      'opensOn': '2026-10-05',
      'isOpen': true,
      'canContribute': true,
      'subjects': [
        {
          'id': 'a',
          'subjectId': 'maths',
          'name': 'Maths',
          'examDay': '2026-10-19',
          'startsAt': '09:00:00',
          'itemCount': 4,
          'checkedByMeCount': 1,
          'resourceCount': 2,
          'contributorCount': 3,
        },
        {
          'id': 'b',
          'subjectId': 'dev',
          'name': 'Dev',
          'itemCount': 4,
          'checkedByMeCount': 3,
          'resourceCount': 0,
          'contributorCount': 1,
        },
      ],
    });

    expect(session.progress, 0.5);
    expect(session.subjects.first.startsAt, '09:00');
    expect(session.daysUntilStart(DateTime(2026, 10, 10, 18)), 9);
    expect(session.isRunning(DateTime(2026, 10, 20)), isTrue);
  });
}
