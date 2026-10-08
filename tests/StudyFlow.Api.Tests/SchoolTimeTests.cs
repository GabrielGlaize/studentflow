using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Time.Testing;
using StudyFlow.Api.Contracts;
using StudyFlow.Api.Tests.Infrastructure;
using StudyFlow.Infrastructure.Time;

namespace StudyFlow.Api.Tests;

public sealed class SchoolClockTests
{
    [Fact]
    public void Now_and_today_follow_paris_time_not_the_server_time_zone()
    {
        // 23h30 UTC le 31 octobre = 0h30 le 1er novembre à Paris (heure d'hiver, UTC+1).
        var clock = CreateClock(new DateTimeOffset(2026, 10, 31, 23, 30, 0, TimeSpan.Zero));

        Assert.Equal(new DateOnly(2026, 11, 1), clock.Today);
        Assert.Equal(new TimeOnly(0, 30), clock.CurrentTime);
    }

    [Fact]
    public void School_times_use_the_right_offset_on_each_side_of_daylight_saving()
    {
        var clock = CreateClock(DateTimeOffset.UtcNow);

        Assert.Equal(TimeSpan.FromHours(2), clock.ToSchoolTime(new DateOnly(2026, 10, 9), new TimeOnly(8, 0)).Offset);
        Assert.Equal(TimeSpan.FromHours(1), clock.ToSchoolTime(new DateOnly(2026, 11, 9), new TimeOnly(8, 0)).Offset);
    }

    [Fact]
    public void A_time_skipped_by_daylight_saving_still_converts()
    {
        var clock = CreateClock(DateTimeOffset.UtcNow);

        // Le 29 mars 2026, 2h30 n'existe pas à Paris.
        var converted = clock.ToSchoolTime(new DateOnly(2026, 3, 29), new TimeOnly(2, 30));

        Assert.Equal(new DateTimeOffset(2026, 3, 29, 1, 30, 0, TimeSpan.Zero), converted.ToUniversalTime());
    }

    private static SchoolClock CreateClock(DateTimeOffset utcNow) => new(
        new FakeTimeProvider(utcNow),
        Options.Create(new SchoolTimeOptions()),
        NullLogger<SchoolClock>.Instance);
}

[Collection(ApiCollection.Name)]
public sealed class DashboardTimeTests(ApiFixture fixture)
{
    [Fact]
    public async Task Next_course_is_computed_in_school_time()
    {
        // 6h30 UTC = 8h30 à Paris. En UTC, le cours de 7h00 serait encore "à venir".
        var now = new DateTimeOffset(2026, 10, 12, 6, 30, 0, TimeSpan.Zero);
        await using var api = fixture.CreateFactory(
            configureServices: services => services.AddSingleton<TimeProvider>(new FakeTimeProvider(now)));

        var scenario = await api.CreateClassWithStudentAsync();
        var subject = await api.CreateSubjectAsync(scenario.Delegate);
        var client = api.As(scenario.Student);
        var today = new DateOnly(2026, 10, 12);

        foreach (var (start, room) in new[] { (new TimeOnly(7, 0), "Passe"), (new TimeOnly(9, 0), "Futur") })
        {
            var created = await client.PostAsJsonAsync("/api/v1/courses",
                new CourseRequest(subject.Id, null, today, start, start.AddHours(1), room));
            await created.ReadSuccessAsync<CourseResponse>();
        }

        var dashboard = await client.GetFromJsonAsync<DashboardResponse>("/api/v1/dashboard", ApiScenario.Json);

        Assert.Equal("Futur", dashboard!.NextCourse?.Room);
    }
}
