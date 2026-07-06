import 'package:studyflow_app/core/demo/demo_session_state.dart';
import 'package:studyflow_app/features/dashboard/data/dashboard_repository.dart';
import 'package:studyflow_app/features/dashboard/domain/dashboard_models.dart';

/// Temporary repository used while the backend connection is being wired.
///
/// It follows the same shape as the real `/api/v1/dashboard` response, so the
/// UI can be developed now and connected to HTTP later with minimal changes.
class DemoDashboardRepository implements DashboardRepository {
  const DemoDashboardRepository();

  @override
  Future<DashboardSummary> getDashboard({String? accessToken}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final now = DateTime.now();
    if (DemoSessionState.hasNoClass(accessToken)) {
      return DashboardSummary(
        generatedAt: now,
        hasClass: false,
        nextCourse: null,
        pinnedAnnouncements: const [],
        upcomingHomework: const [],
        personalTasks: [
          PersonalTaskSummary(
            id: 'demo-task-no-class-1',
            title: 'Préparer mon CV alternance',
            category: 'apprenticeship',
            isDone: false,
          ),
          PersonalTaskSummary(
            id: 'demo-task-no-class-2',
            title: 'Relancer une entreprise',
            category: 'apprenticeship',
            isDone: false,
            deadline: now.add(const Duration(hours: 5)),
          ),
        ],
        todayEvents: [
          PersonalEventSummary(
            id: 'demo-event-no-class-1',
            title: 'Entretien alternance',
            day: now,
            startsAt: '15:00',
            endsAt: '15:30',
            category: 'apprenticeship',
          ),
        ],
      );
    }

    return DashboardSummary(
      generatedAt: now,
      hasClass: true,
      nextCourse: CourseSummary(
        id: 'demo-course-1',
        subjectName: 'Flutter — navigation et état',
        day: now,
        startsAt: '10:15',
        endsAt: '12:15',
        room: 'B204',
        teacherName: 'Mme Dupont',
      ),
      pinnedAnnouncements: const [
        ClassAnnouncementSummary(
          id: 'demo-announcement-1',
          content: 'La salle du partiel a changé : rendez-vous en B204.',
          authorName: 'Délégué',
        ),
      ],
      upcomingHomework: [
        HomeworkSummary(
          id: 'demo-homework-1',
          title: 'Rendre le dossier d’anglais',
          deadline: now.add(const Duration(days: 1)),
          isDone: false,
          notificationsEnabled: true,
        ),
        HomeworkSummary(
          id: 'demo-homework-2',
          title: 'Préparer la présentation StudyFlow',
          deadline: now.add(const Duration(days: 3)),
          isDone: false,
          notificationsEnabled: true,
        ),
      ],
      personalTasks: [
        PersonalTaskSummary(
          id: 'demo-task-1',
          title: 'Relancer une entreprise',
          category: 'apprenticeship',
          isDone: false,
          deadline: now.add(const Duration(hours: 5)),
        ),
      ],
      todayEvents: [
        PersonalEventSummary(
          id: 'demo-event-1',
          title: 'Entretien alternance',
          day: now,
          startsAt: '15:00',
          endsAt: '15:30',
          category: 'apprenticeship',
        ),
      ],
    );
  }
}
