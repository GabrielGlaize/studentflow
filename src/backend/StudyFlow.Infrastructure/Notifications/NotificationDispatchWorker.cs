using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using StudyFlow.Application.Notifications;
using StudyFlow.Application.Time;
using StudyFlow.Domain.Notifications;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Infrastructure.Notifications;

public sealed class NotificationDispatchWorker(
    IServiceScopeFactory scopeFactory,
    IOptions<NotificationWorkerOptions> options,
    ILogger<NotificationDispatchWorker> logger) : BackgroundService
{
    private const int ErrorMessageMaxLength = 1000;

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
            try
            {
                await DispatchDueNotificationsAsync(stoppingToken);
            }
            catch (Exception exception) when (!stoppingToken.IsCancellationRequested)
            {
                // Une exception non gérée dans un BackgroundService arrête toute l'API (.NET 8) :
                // une base momentanément indisponible ne doit coûter qu'un tour de boucle.
                logger.LogError(exception, "Notification dispatch failed. The worker will retry at the next tick.");
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }

    private async Task DispatchDueNotificationsAsync(CancellationToken cancellationToken)
    {
        await using var scope = scopeFactory.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<StudyFlowDbContext>();
        var planner = scope.ServiceProvider.GetRequiredService<INotificationReminderPlanner>();
        var sender = scope.ServiceProvider.GetRequiredService<IPushNotificationSender>();
        var clock = scope.ServiceProvider.GetRequiredService<ISchoolClock>();
        var workerOptions = scope.ServiceProvider.GetRequiredService<IOptions<NotificationWorkerOptions>>().Value;

        var now = clock.UtcNow;
        var windowStart = now.AddMinutes(-Math.Clamp(workerOptions.LookBehindMinutes, 0, 1440));
        var windowEnd = now;

        var classIds = await dbContext.SchoolClasses
            .AsNoTracking()
            .Where(x => x.IsActive)
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

        foreach (var reminder in await planner.PlanPersonalRemindersAsync(windowStart, windowEnd, cancellationToken))
        {
            await DispatchOnceAsync(dbContext, sender, reminder, cancellationToken);
        }
    }

    private static async Task DispatchOnceAsync(
        StudyFlowDbContext dbContext,
        IPushNotificationSender sender,
        NotificationReminderCandidate reminder,
        CancellationToken cancellationToken)
    {
        // Une ligne par rappel (index unique) : un envoi en échec est retenté en mettant à jour
        // la même ligne, sinon l'insertion suivante violerait l'index.
        var delivery = await dbContext.NotificationDeliveries.SingleOrDefaultAsync(
            x => x.UserId == reminder.UserId
                && x.Type == reminder.Type
                && x.RelatedEntityId == reminder.RelatedEntityId
                && x.ScheduledAt == reminder.ScheduledAt,
            cancellationToken);

        if (delivery?.Status == NotificationDeliveryStatus.Sent) return;

        if (delivery is null)
        {
            delivery = new NotificationDelivery
            {
                UserId = reminder.UserId,
                Type = reminder.Type,
                RelatedEntityId = reminder.RelatedEntityId,
                ScheduledAt = reminder.ScheduledAt
            };
            dbContext.NotificationDeliveries.Add(delivery);
        }

        delivery.ProcessedAt = DateTimeOffset.UtcNow;

        try
        {
            await sender.SendAsync(
                [reminder.UserId],
                new PushNotification(reminder.Type, reminder.RelatedEntityId, reminder.Title, reminder.Body),
                cancellationToken);
            delivery.Status = NotificationDeliveryStatus.Sent;
            delivery.ErrorMessage = null;
        }
        catch (Exception exception) when (!cancellationToken.IsCancellationRequested)
        {
            delivery.Status = NotificationDeliveryStatus.Failed;
            delivery.ErrorMessage = exception.Message.Length <= ErrorMessageMaxLength
                ? exception.Message
                : exception.Message[..ErrorMessageMaxLength];
        }

        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
