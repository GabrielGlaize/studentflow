using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using StudyFlow.Application.Notifications;
using StudyFlow.Domain.Notifications;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Infrastructure.Notifications;

public sealed class NotificationDispatchWorker(
    IServiceScopeFactory scopeFactory,
    IOptions<NotificationWorkerOptions> options,
    ILogger<NotificationDispatchWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var workerOptions = options.Value;
        if (!workerOptions.Enabled)
        {
            logger.LogInformation("Notification worker is disabled. Set NotificationWorker:Enabled=true to activate it.");
            return;
        }

        var interval = TimeSpan.FromSeconds(Math.Clamp(workerOptions.IntervalSeconds, 10, 3600));
        using var timer = new PeriodicTimer(interval);

        logger.LogInformation("Notification worker started with interval {IntervalSeconds}s.", interval.TotalSeconds);

        do
        {
            await DispatchDueNotificationsAsync(stoppingToken);
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }

    private async Task DispatchDueNotificationsAsync(CancellationToken cancellationToken)
    {
        await using var scope = scopeFactory.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<StudyFlowDbContext>();
        var planner = scope.ServiceProvider.GetRequiredService<INotificationReminderPlanner>();
        var sender = scope.ServiceProvider.GetRequiredService<INotificationSender>();
        var workerOptions = scope.ServiceProvider.GetRequiredService<IOptions<NotificationWorkerOptions>>().Value;

        var now = DateTimeOffset.Now;
        var windowStart = now.AddMinutes(-Math.Clamp(workerOptions.LookBehindMinutes, 0, 1440));
        var windowEnd = now;

        var classIds = await dbContext.SchoolClasses
            .AsNoTracking()
            .Select(x => x.Id)
            .ToListAsync(cancellationToken);

        foreach (var classId in classIds)
        {
            var reminders = await planner.PlanClassRemindersAsync(classId, windowStart, windowEnd, cancellationToken);
            foreach (var reminder in reminders)
            {
                await DispatchOnceAsync(dbContext, sender, reminder, cancellationToken);
            }
        }
    }

    private static async Task DispatchOnceAsync(
        StudyFlowDbContext dbContext,
        INotificationSender sender,
        NotificationReminderCandidate reminder,
        CancellationToken cancellationToken)
    {
        var alreadyProcessed = await dbContext.NotificationDeliveries.AnyAsync(
            x => x.UserId == reminder.UserId
                && x.Type == reminder.Type
                && x.RelatedEntityId == reminder.RelatedEntityId
                && x.ScheduledAt == reminder.ScheduledAt
                && x.Status == NotificationDeliveryStatus.Sent,
            cancellationToken);

        if (alreadyProcessed) return;

        var delivery = new NotificationDelivery
        {
            UserId = reminder.UserId,
            Type = reminder.Type,
            RelatedEntityId = reminder.RelatedEntityId,
            ScheduledAt = reminder.ScheduledAt,
            ProcessedAt = DateTimeOffset.UtcNow
        };

        try
        {
            await sender.SendAsync(reminder, cancellationToken);
            delivery.Status = NotificationDeliveryStatus.Sent;
        }
        catch (Exception exception)
        {
            delivery.Status = NotificationDeliveryStatus.Failed;
            delivery.ErrorMessage = exception.Message;
        }

        dbContext.NotificationDeliveries.Add(delivery);
        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
