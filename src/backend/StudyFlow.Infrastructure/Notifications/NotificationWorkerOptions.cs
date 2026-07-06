namespace StudyFlow.Infrastructure.Notifications;

public sealed class NotificationWorkerOptions
{
    public const string SectionName = "NotificationWorker";

    public bool Enabled { get; set; }
    public int IntervalSeconds { get; set; } = 60;
    public int LookBehindMinutes { get; set; } = 2;
}
