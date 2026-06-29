namespace StudyFlow.Api.Contracts;

public sealed record DashboardResponse(
    DateTimeOffset GeneratedAt,
    bool HasClass,
    CourseResponse? NextCourse,
    IReadOnlyCollection<ClassAnnouncementResponse> PinnedAnnouncements,
    IReadOnlyCollection<HomeworkResponse> UpcomingHomework,
    IReadOnlyCollection<PersonalTaskResponse> PersonalTasks,
    IReadOnlyCollection<PersonalEventResponse> TodayEvents);
