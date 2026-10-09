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

    [Fact]
    public async Task Homework_can_be_marked_as_an_evaluation()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();
        var subject = await fixture.Api.CreateSubjectAsync(scenario.Delegate);
        var day = DateOnly.FromDateTime(DateTime.UtcNow.AddDays(5));
        var course = await fixture.Api.CreateCourseAsync(scenario.Student, subject.Id, day);
        var client = fixture.Api.As(scenario.Student);
        var deadline = DateTimeOffset.UtcNow.AddDays(5);

        var created = await (await client.PostAsJsonAsync("/api/v1/homework",
                new HomeworkRequest("Contrôle chapitre 4", null, deadline, course.Id, IsEvaluation: true)))
            .ReadSuccessAsync<HomeworkResponse>();
        Assert.True(created.IsEvaluation);

        // Toute la classe le voit comme une évaluation.
        var listed = await fixture.Api.As(scenario.Delegate)
            .GetFromJsonAsync<HomeworkResponse[]>("/api/v1/homework", ApiScenario.Json);
        Assert.True(listed!.Single(x => x.Id == created.Id).IsEvaluation);

        var updated = await (await client.PutAsJsonAsync($"/api/v1/homework/{created.Id}",
                new HomeworkUpdateRequest("Exercices chapitre 4", null, deadline, course.Id)))
            .ReadSuccessAsync<HomeworkResponse>();
        Assert.False(updated.IsEvaluation);
    }
}

