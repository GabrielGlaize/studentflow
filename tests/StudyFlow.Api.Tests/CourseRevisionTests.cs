using System.Net;
using System.Net.Http.Json;
using StudyFlow.Api.Contracts;
using StudyFlow.Api.Tests.Infrastructure;

namespace StudyFlow.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class CourseRevisionTests(ApiFixture fixture)
{
    private static readonly DateOnly Day = new(2026, 11, 3);

    [Fact]
    public async Task Restore_latest_undoes_the_last_update()
    {
        var (client, course, subjectId) = await CreateCourseAsync();

        var updated = await client.PutAsJsonAsync($"/api/v1/courses/{course.Id}", new CourseUpdateRequest(
            subjectId, null, Day, new TimeOnly(14, 0), new TimeOnly(15, 0), "Amphi", false, course.Version));
        var afterUpdate = await updated.ReadSuccessAsync<CourseResponse>();
        Assert.Equal("Amphi", afterUpdate.Room);

        var restored = await client.PostAsync($"/api/v1/courses/{course.Id}/restore-latest", null);
        var afterRestore = await restored.ReadSuccessAsync<CourseResponse>();

        Assert.Equal("B204", afterRestore.Room);
        Assert.Equal(new TimeOnly(9, 0), afterRestore.StartsAt);
    }

    [Fact]
    public async Task Restore_latest_brings_back_a_deleted_course()
    {
        var (client, course, _) = await CreateCourseAsync();

        var deleted = await client.DeleteAsync($"/api/v1/courses/{course.Id}");
        Assert.Equal(HttpStatusCode.NoContent, deleted.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/api/v1/courses/{course.Id}")).StatusCode);

        var restored = await client.PostAsync($"/api/v1/courses/{course.Id}/restore-latest", null);
        Assert.Equal(HttpStatusCode.OK, restored.StatusCode);

        var current = await client.GetAsync($"/api/v1/courses/{course.Id}");
        Assert.Equal("B204", (await current.ReadSuccessAsync<CourseResponse>()).Room);
    }

    [Fact]
    public async Task Restore_latest_on_a_new_course_has_nothing_to_undo()
    {
        var (client, course, _) = await CreateCourseAsync();

        var response = await client.PostAsync($"/api/v1/courses/{course.Id}/restore-latest", null);

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }

    [Fact]
    public async Task Any_approved_student_can_correct_a_course_without_delegate_approval()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();
        var subject = await fixture.Api.CreateSubjectAsync(scenario.Delegate);
        var created = await fixture.Api.As(scenario.Delegate).PostAsJsonAsync("/api/v1/courses", new CourseRequest(
            subject.Id, null, Day, new TimeOnly(9, 0), new TimeOnly(10, 0), "B204"));
        var course = await created.ReadSuccessAsync<CourseResponse>();

        var corrected = await fixture.Api.As(scenario.Student).PutAsJsonAsync($"/api/v1/courses/{course.Id}", new CourseUpdateRequest(
            subject.Id, null, Day, new TimeOnly(9, 0), new TimeOnly(10, 0), "C101", false, course.Version));

        Assert.Equal("C101", (await corrected.ReadSuccessAsync<CourseResponse>()).Room);
    }

    private async Task<(HttpClient Client, CourseResponse Course, Guid SubjectId)> CreateCourseAsync()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();
        var subject = await fixture.Api.CreateSubjectAsync(scenario.Delegate);
        var client = fixture.Api.As(scenario.Student);

        var created = await client.PostAsJsonAsync("/api/v1/courses", new CourseRequest(
            subject.Id, null, Day, new TimeOnly(9, 0), new TimeOnly(10, 0), "B204"));
        return (client, await created.ReadSuccessAsync<CourseResponse>(), subject.Id);
    }
}
