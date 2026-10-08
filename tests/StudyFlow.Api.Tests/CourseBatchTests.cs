using System.Net;
using System.Net.Http.Json;
using StudyFlow.Api.Contracts;
using StudyFlow.Api.Tests.Infrastructure;

namespace StudyFlow.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class CourseBatchTests(ApiFixture fixture)
{
    private static readonly DateOnly Monday = new(2026, 11, 16);

    [Fact]
    public async Task Several_slots_are_created_in_one_request()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();
        var subject = await fixture.Api.CreateSubjectAsync(scenario.Delegate);
        var client = fixture.Api.As(scenario.Student);

        var response = await client.PostAsJsonAsync("/api/v1/courses/batch", new CourseBatchRequest([
            Slot(subject.Id, Monday, 8, 0, 9, 30),
            Slot(subject.Id, Monday, 9, 45, 11, 15),
            Slot(subject.Id, Monday, 11, 30, 13, 0),
            Slot(subject.Id, Monday.AddDays(7), 8, 0, 9, 30),
        ]));

        var courses = await response.ReadSuccessAsync<CourseResponse[]>();
        Assert.Equal(4, courses.Length);
        Assert.Equal([new TimeOnly(8, 0), new TimeOnly(9, 45), new TimeOnly(11, 30), new TimeOnly(8, 0)], courses.Select(x => x.StartsAt));

        var listed = await client.GetFromJsonAsync<CourseResponse[]>(
            $"/api/v1/courses?from={Monday:yyyy-MM-dd}&to={Monday.AddDays(7):yyyy-MM-dd}", ApiScenario.Json);
        Assert.Equal(4, listed!.Length);
    }

    [Fact]
    public async Task Overlapping_slots_create_nothing()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();
        var subject = await fixture.Api.CreateSubjectAsync(scenario.Delegate);
        var client = fixture.Api.As(scenario.Student);

        var response = await client.PostAsJsonAsync("/api/v1/courses/batch", new CourseBatchRequest([
            Slot(subject.Id, Monday, 8, 0, 9, 30),
            Slot(subject.Id, Monday, 9, 0, 10, 0),
        ]));

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        var listed = await client.GetFromJsonAsync<CourseResponse[]>(
            $"/api/v1/courses?from={Monday:yyyy-MM-dd}&to={Monday:yyyy-MM-dd}", ApiScenario.Json);
        Assert.Empty(listed!);
    }

    [Fact]
    public async Task A_slot_overlapping_an_existing_course_creates_nothing()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();
        var subject = await fixture.Api.CreateSubjectAsync(scenario.Delegate);
        await fixture.Api.CreateCourseAsync(scenario.Student, subject.Id, Monday.AddDays(7), new TimeOnly(8, 30));

        var response = await fixture.Api.As(scenario.Student).PostAsJsonAsync("/api/v1/courses/batch", new CourseBatchRequest([
            Slot(subject.Id, Monday, 8, 0, 9, 30),
            Slot(subject.Id, Monday.AddDays(7), 8, 0, 9, 30),
        ]));

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }

    private static CourseRequest Slot(Guid subjectId, DateOnly day, int startHour, int startMinute, int endHour, int endMinute) =>
        new(subjectId, null, day, new TimeOnly(startHour, startMinute), new TimeOnly(endHour, endMinute), "B204");
}
