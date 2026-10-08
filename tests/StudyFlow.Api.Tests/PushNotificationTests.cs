using System.Collections.Concurrent;
using System.Net;
using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using StudyFlow.Api.Contracts;
using StudyFlow.Api.Tests.Infrastructure;
using StudyFlow.Application.Notifications;

namespace StudyFlow.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class PushNotificationTests(ApiFixture fixture)
{
    [Fact]
    public async Task A_new_announcement_notifies_the_class_but_not_its_author()
    {
        var sender = new RecordingPushSender();
        await using var api = fixture.CreateFactory(
            configureServices: services => services.AddSingleton<IPushNotificationSender>(sender));
        var scenario = await api.CreateClassWithStudentAsync();

        var created = await api.As(scenario.Delegate).PostAsJsonAsync("/api/v1/class-announcements",
            new ClassAnnouncementRequest("Le cours de jeudi est déplacé en salle B12.", IsPinned: true));
        var announcement = await created.ReadSuccessAsync<ClassAnnouncementResponse>();

        var (userIds, notification) = Assert.Single(sender.Sent);
        Assert.Equal([scenario.Student.User.Id], userIds);
        Assert.Equal("announcement", notification.Type);
        Assert.Equal(announcement.Id, notification.RelatedEntityId);
        Assert.Equal("Annonce épinglée", notification.Title);
    }

    [Fact]
    public async Task An_announcement_is_published_even_if_push_delivery_fails()
    {
        await using var api = fixture.CreateFactory(
            configureServices: services => services.AddSingleton<IPushNotificationSender>(new FailingPushSender()));
        var scenario = await api.CreateClassWithStudentAsync();

        var created = await api.As(scenario.Delegate).PostAsJsonAsync("/api/v1/class-announcements",
            new ClassAnnouncementRequest("Réunion à 12h"));

        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
    }

    [Fact]
    public async Task A_device_token_is_attached_to_the_last_signed_in_user()
    {
        var first = await fixture.Api.RegisterAsync();
        var second = await fixture.Api.RegisterAsync();
        var token = $"fcm-token-{Guid.NewGuid():N}";

        await fixture.Api.As(first).PostAsJsonAsync("/api/v1/notifications/devices", new NotificationDeviceRequest(token, "android"));
        var moved = await fixture.Api.As(second).PostAsJsonAsync("/api/v1/notifications/devices", new NotificationDeviceRequest(token, "android"));
        Assert.Equal(HttpStatusCode.OK, moved.StatusCode);

        var firstDevices = await fixture.Api.As(first)
            .GetFromJsonAsync<NotificationDeviceResponse[]>("/api/v1/notifications/devices", ApiScenario.Json);
        var secondDevices = await fixture.Api.As(second)
            .GetFromJsonAsync<NotificationDeviceResponse[]>("/api/v1/notifications/devices", ApiScenario.Json);
        Assert.Empty(firstDevices!);
        Assert.Single(secondDevices!);
    }

    private sealed class RecordingPushSender : IPushNotificationSender
    {
        public ConcurrentQueue<(IReadOnlyCollection<Guid> UserIds, PushNotification Notification)> Sent { get; } = new();

        public Task SendAsync(IReadOnlyCollection<Guid> userIds, PushNotification notification, CancellationToken cancellationToken)
        {
            Sent.Enqueue((userIds, notification));
            return Task.CompletedTask;
        }
    }

    private sealed class FailingPushSender : IPushNotificationSender
    {
        public Task SendAsync(IReadOnlyCollection<Guid> userIds, PushNotification notification, CancellationToken cancellationToken) =>
            throw new InvalidOperationException("Firebase indisponible");
    }
}
