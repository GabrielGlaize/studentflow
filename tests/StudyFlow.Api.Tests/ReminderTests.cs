using System.Net;
using System.Net.Http.Json;
using StudyFlow.Api.Contracts;
using StudyFlow.Api.Tests.Infrastructure;
using StudyFlow.Application.Notifications;

namespace StudyFlow.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class ReminderTests(ApiFixture fixture)
{
    [Fact]
    public async Task A_task_keeps_the_chosen_reminder_delay()
    {
        var session = await fixture.Api.RegisterAsync();
        var client = fixture.Api.As(session);

        var created = await (await client.PostAsJsonAsync("/api/v1/personal-agenda/tasks", new PersonalTaskRequest(
                "Relire le rapport", null, DateTimeOffset.UtcNow.AddDays(3), "school",
                NotificationsEnabled: true, ReminderMinutesBefore: 180)))
            .ReadSuccessAsync<PersonalTaskResponse>();

        Assert.Equal(180, created.ReminderMinutesBefore);
    }

    [Fact]
    public async Task A_reminder_more_than_30_days_ahead_is_refused()
    {
        var session = await fixture.Api.RegisterAsync();

        var response = await fixture.Api.As(session).PostAsJsonAsync("/api/v1/personal-agenda/events", new PersonalEventRequest(
            "Entretien", DateOnly.FromDateTime(DateTime.UtcNow.AddDays(2)), new TimeOnly(14, 0), new TimeOnly(15, 0), "apprenticeship",
            NotificationsEnabled: true, ReminderMinutesBefore: 31 * 24 * 60));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Each_student_chooses_when_a_homework_reminds_them()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();
        var subject = await fixture.Api.CreateSubjectAsync(scenario.Delegate);
        var course = await fixture.Api.CreateCourseAsync(scenario.Delegate, subject.Id);
        var homework = await (await fixture.Api.As(scenario.Delegate).PostAsJsonAsync("/api/v1/homework",
                new HomeworkRequest("Exposé", null, DateTimeOffset.UtcNow.AddMinutes(150), course.Id)))
            .ReadSuccessAsync<HomeworkResponse>();
        Assert.Equal(24 * 60, homework.ReminderMinutesBefore);

        var student = fixture.Api.As(scenario.Student);
        await student.PostAsJsonAsync("/api/v1/notifications/devices", new NotificationDeviceRequest($"token-{Guid.NewGuid():N}", "android"));
        var updated = await (await student.PutAsJsonAsync($"/api/v1/homework/{homework.Id}/progress",
            new HomeworkProgressRequest(false, true, ReminderMinutesBefore: 120))).ReadSuccessAsync<HomeworkResponse>();
        Assert.Equal(120, updated.ReminderMinutesBefore);

        // Échéance dans 2 h 30, rappel 2 h avant : prévu dans 30 min, pour cet élève seulement.
        var preview = await fixture.Api.As(scenario.Delegate).GetFromJsonAsync<NotificationReminderCandidateResponse[]>(
            "/api/v1/notifications/due-preview?lookBehindMinutes=0&lookAheadMinutes=60", ApiScenario.Json);
        var reminder = Assert.Single(preview!, x => x.Type == "homework");
        Assert.Equal(scenario.Student.User.Id, reminder.UserId);
        Assert.Equal("Devoir à rendre dans 2 h", reminder.Title);
    }

    [Theory]
    [InlineData(0, "maintenant")]
    [InlineData(15, "dans 15 min")]
    [InlineData(90, "dans 1 h 30")]
    [InlineData(1440, "demain")]
    [InlineData(2880, "dans 2 jours")]
    [InlineData(10080, "dans 1 semaine")]
    public void Reminder_delays_read_naturally(int minutes, string expected) =>
        Assert.Equal(expected, ReminderWording.Relative(minutes));
}
