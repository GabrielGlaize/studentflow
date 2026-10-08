using System.Net;
using System.Net.Http.Json;
using StudyFlow.Api.Contracts;
using StudyFlow.Api.Tests.Infrastructure;

namespace StudyFlow.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class HomeworkTests(ApiFixture fixture)
{
    [Fact]
    public async Task Homework_must_be_linked_to_a_course()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();

        var response = await fixture.Api.As(scenario.Student).PostAsJsonAsync("/api/v1/homework",
            new HomeworkRequest("Exercices 3 à 5", null, DateTimeOffset.UtcNow.AddDays(2)));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Homework_shows_the_subject_and_day_of_its_course()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();
        var subject = await fixture.Api.CreateSubjectAsync(scenario.Delegate);
        var day = DateOnly.FromDateTime(DateTime.UtcNow.AddDays(4));
        var course = await fixture.Api.CreateCourseAsync(scenario.Student, subject.Id, day);
        var client = fixture.Api.As(scenario.Student);

        var created = await (await client.PostAsJsonAsync("/api/v1/homework",
                new HomeworkRequest("Exercices 3 à 5", null, DateTimeOffset.UtcNow.AddDays(4), course.Id)))
            .ReadSuccessAsync<HomeworkResponse>();
        Assert.Equal(subject.Name, created.SubjectName);
        Assert.Equal(day, created.CourseDay);

        var listed = await client.GetFromJsonAsync<HomeworkResponse[]>("/api/v1/homework", ApiScenario.Json);
        Assert.Equal(subject.Name, listed!.Single(x => x.Id == created.Id).SubjectName);
    }
}
