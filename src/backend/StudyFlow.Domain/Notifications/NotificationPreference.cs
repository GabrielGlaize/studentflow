using StudyFlow.Domain.Common;

namespace StudyFlow.Domain.Notifications;

public sealed class NotificationPreference : Entity
{
    public Guid UserId { get; set; }
    public bool CoursesEnabled { get; set; } = true;
    public bool HomeworkEnabled { get; set; } = true;
    public bool ApprenticeshipsEnabled { get; set; }
    public int CourseReminderMinutes { get; set; } = 5;
}
