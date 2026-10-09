using System.Net.Http.Json;
using StudyFlow.Api.Contracts;
using StudyFlow.Api.Tests.Infrastructure;
using StudyFlow.Domain.Notifications;

namespace StudyFlow.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class QuietHoursTests(ApiFixture fixture)
{
    [Fact]
    public async Task Quiet_hours_and_pause_are_saved_with_the_notification_preferences()
    {
        var session = await fixture.Api.RegisterAsync();
        var client = fixture.Api.As(session);
        var pauseEnd = DateTimeOffset.UtcNow.AddHours(2);

        var saved = await (await client.PutAsJsonAsync("/api/v1/notifications/preferences",
                new NotificationSettingsRequest(true, true, false, 10,
                    QuietHoursEnabled: true,
                    QuietHoursStart: new TimeOnly(21, 30),
                    QuietHoursEnd: new TimeOnly(6, 45),
                    MutedUntil: pauseEnd)))
            .ReadSuccessAsync<NotificationSettingsResponse>();
        Assert.True(saved.QuietHoursEnabled);
        Assert.Equal(new TimeOnly(21, 30), saved.QuietHoursStart);
        Assert.NotNull(saved.MutedUntil);

        // Une ancienne version de l'app n'envoie pas ces champs : rien n'est perdu.
        var legacy = await (await client.PutAsJsonAsync("/api/v1/notifications/preferences",
                new NotificationSettingsRequest(true, false, false, 10)))
            .ReadSuccessAsync<NotificationSettingsResponse>();
        Assert.True(legacy.QuietHoursEnabled);
        Assert.Equal(new TimeOnly(6, 45), legacy.QuietHoursEnd);
        Assert.NotNull(legacy.MutedUntil);

        // Un instant passé arrête la pause.
        var resumed = await (await client.PutAsJsonAsync("/api/v1/notifications/preferences",
                new NotificationSettingsRequest(true, false, false, 10,
                    MutedUntil: DateTimeOffset.UnixEpoch)))
            .ReadSuccessAsync<NotificationSettingsResponse>();
        Assert.Null(resumed.MutedUntil);
    }

    [Fact]
    public void Quiet_hours_can_span_midnight_and_a_pause_mutes_everything()
    {
        var paris = TimeZoneInfo.FindSystemTimeZoneById("Europe/Paris");
        var preference = new NotificationPreference
        {
            QuietHoursEnabled = true,
            QuietHoursStart = new TimeOnly(22, 0),
            QuietHoursEnd = new TimeOnly(7, 0)
        };
        DateTimeOffset At(int day, int hour) => new(2026, 10, day, hour, 0, 0, TimeSpan.FromHours(2));

        Assert.True(preference.IsQuietAt(At(9, 23), paris));
        Assert.True(preference.IsQuietAt(At(10, 6), paris));
        Assert.False(preference.IsQuietAt(At(10, 7), paris));
        Assert.False(preference.IsQuietAt(At(9, 18), paris));

        preference.QuietHoursEnabled = false;
        preference.MutedUntil = At(9, 20);
        Assert.True(preference.IsQuietAt(At(9, 18), paris));
        Assert.False(preference.IsQuietAt(At(9, 21), paris));
    }
}
