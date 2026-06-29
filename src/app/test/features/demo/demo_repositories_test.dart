import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow_app/core/demo/demo_session_state.dart';
import 'package:studyflow_app/features/agenda/data/demo_agenda_repository.dart';
import 'package:studyflow_app/features/apprenticeships/data/demo_apprenticeship_repository.dart';
import 'package:studyflow_app/features/apprenticeships/domain/apprenticeship_models.dart';
import 'package:studyflow_app/features/classes/data/demo_class_management_repository.dart';
import 'package:studyflow_app/features/classes/data/demo_class_resource_repository.dart';
import 'package:studyflow_app/features/dashboard/data/demo_dashboard_repository.dart';
import 'package:studyflow_app/features/schedule/data/demo_course_repository.dart';

void main() {
  test(
    'les repositories demo respectent le mode futur eleve sans classe',
    () async {
      const token = DemoSessionState.noClassToken;

      final dashboard = await const DemoDashboardRepository().getDashboard(
        accessToken: token,
      );
      final currentClass = await const DemoClassManagementRepository()
          .getCurrentClass(accessToken: token);
      final agenda = await const DemoAgendaRepository().getAgenda(
        taskCategory: 'apprenticeship',
        accessToken: token,
      );
      final courses = await const DemoCourseRepository().listCourses(
        from: DateTime(2026, 6, 22),
        to: DateTime(2026, 6, 28),
        accessToken: token,
      );
      final subjects = await const DemoClassResourceRepository().listSubjects(
        accessToken: token,
      );
      final teachers = await const DemoClassResourceRepository().listTeachers(
        accessToken: token,
      );

      expect(dashboard.hasClass, isFalse);
      expect(dashboard.nextCourse, isNull);
      expect(currentClass, isNull);
      expect(agenda.homework, isEmpty);
      expect(agenda.tasks, isNotEmpty);
      expect(courses, isEmpty);
      expect(subjects, isEmpty);
      expect(teachers, isEmpty);
    },
  );

  test('le createur de classe demo devient delegue', () async {
    final currentClass = await const DemoClassManagementRepository()
        .getCurrentClass(accessToken: DemoSessionState.createdClassToken);

    expect(currentClass?.isDelegate, isTrue);
    expect(currentClass?.accessCode, 'NEW-42');
  });

  test(
    'la gestion de classe demo permet refus et regeneration du code',
    () async {
      const repository = DemoClassManagementRepository();

      final accessCode = await repository.regenerateAccessCode(
        accessToken: DemoSessionState.classMemberToken,
      );
      final currentClass = await repository.getCurrentClass(
        accessToken: DemoSessionState.classMemberToken,
      );

      expect(accessCode.accessCode, 'SIO1-99');
      expect(currentClass?.accessCode, 'SIO1-99');

      await repository.rejectRequest(
        requestId: 'request-unknown',
        accessToken: DemoSessionState.classMemberToken,
      );
    },
  );

  test('la recherche alternance demo permet favoris et recherches', () async {
    const repository = DemoApprenticeshipRepository();

    final savedSearch = await repository.saveSearch(
      search: ApprenticeshipSavedSearch(
        id: 'pending',
        name: 'Flutter Lyon',
        keywords: 'flutter',
        location: 'Lyon',
        createdAt: DateTime(2026, 6, 25),
      ),
    );
    final searches = await repository.listSavedSearches();

    expect(savedSearch.keywords, 'flutter');
    expect(searches.first.name, 'Flutter Lyon');

    final opportunities = await repository.searchOpportunities(
      keywords: 'flutter',
      location: 'Lyon',
    );
    final favorite = await repository.saveFavoriteOffer(
      opportunity: opportunities.first,
    );
    final favorites = await repository.listFavoriteOffers();

    expect(favorites.single.id, favorite.id);
    expect(favorites.single.title, opportunities.first.title);

    await repository.deleteFavoriteOffer(favoriteId: favorite.id);
    expect(await repository.listFavoriteOffers(), isEmpty);
  });
}
