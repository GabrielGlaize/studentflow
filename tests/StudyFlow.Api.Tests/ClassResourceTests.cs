using System.Net;
using System.Net.Http.Json;
using StudyFlow.Api.Contracts;
using StudyFlow.Api.Tests.Infrastructure;

namespace StudyFlow.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class ClassResourceTests(ApiFixture fixture)
{
    [Fact]
    public async Task A_deleted_subject_or_teacher_can_be_added_again()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();
        var client = fixture.Api.As(scenario.Delegate);

        var subject = await (await client.PostAsJsonAsync("/api/v1/class-resources/subjects", new SubjectRequest("Anglais")))
            .ReadSuccessAsync<SubjectResponse>();
        var teacher = await (await client.PostAsJsonAsync("/api/v1/class-resources/teachers", new TeacherRequest("M. Dupont", null)))
            .ReadSuccessAsync<TeacherResponse>();

        await client.DeleteAsync($"/api/v1/class-resources/subjects/{subject.Id}");
        await client.DeleteAsync($"/api/v1/class-resources/teachers/{teacher.Id}");

        // Recréer sous le même nom (même avec une casse différente) réactive l'élément.
        var subjectAgain = await (await client.PostAsJsonAsync("/api/v1/class-resources/subjects", new SubjectRequest("anglais")))
            .ReadSuccessAsync<SubjectResponse>();
        var teacherAgain = await (await client.PostAsJsonAsync("/api/v1/class-resources/teachers", new TeacherRequest("m. dupont", null)))
            .ReadSuccessAsync<TeacherResponse>();

        Assert.Equal(subject.Id, subjectAgain.Id);
        Assert.Equal("anglais", subjectAgain.Name);
        Assert.Equal(teacher.Id, teacherAgain.Id);

        var duplicate = await client.PostAsJsonAsync("/api/v1/class-resources/subjects", new SubjectRequest("Anglais"));
        Assert.Equal(HttpStatusCode.Conflict, duplicate.StatusCode);
    }

    [Fact]
    public async Task Subjects_and_teachers_are_linked_both_ways()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();
        var client = fixture.Api.As(scenario.Delegate);

        var maths = await fixture.Api.CreateSubjectAsync(scenario.Delegate);
        var physics = await fixture.Api.CreateSubjectAsync(scenario.Delegate);

        // Un intervenant peut enseigner plusieurs matières…
        var martin = await (await client.PostAsJsonAsync("/api/v1/class-resources/teachers",
                new TeacherRequest("Mme Martin", null, [maths.Id, physics.Id])))
            .ReadSuccessAsync<TeacherResponse>();
        // … et une matière peut avoir plusieurs intervenants.
        var bernard = await (await client.PostAsJsonAsync("/api/v1/class-resources/teachers",
                new TeacherRequest("M. Bernard", null, [maths.Id])))
            .ReadSuccessAsync<TeacherResponse>();

        var subjects = await client.GetFromJsonAsync<SubjectResponse[]>("/api/v1/class-resources/subjects", ApiScenario.Json);
        Assert.Equal(new[] { bernard.Id, martin.Id }.Order(), subjects!.Single(x => x.Id == maths.Id).TeacherIds.Order());
        Assert.Equal([martin.Id], subjects!.Single(x => x.Id == physics.Id).TeacherIds);

        // Modifier la matière remplace ses intervenants.
        var updated = await client.PutAsJsonAsync($"/api/v1/class-resources/subjects/{physics.Id}",
            new SubjectRequest("Physique", [bernard.Id]));
        Assert.Equal([bernard.Id], (await updated.ReadSuccessAsync<SubjectResponse>()).TeacherIds);

        var teachers = await client.GetFromJsonAsync<TeacherResponse[]>("/api/v1/class-resources/teachers", ApiScenario.Json);
        Assert.Equal([maths.Id], teachers!.Single(x => x.Id == martin.Id).SubjectIds);
        Assert.Equal(new[] { maths.Id, physics.Id }.Order(), teachers!.Single(x => x.Id == bernard.Id).SubjectIds.Order());

        // Les intervenants sont triés sur le nom, sans tenir compte de la civilité.
        Assert.Equal(["M. Bernard", "Mme Martin"], teachers!.Select(x => x.DisplayName));
    }

    [Fact]
    public async Task A_teacher_cannot_be_linked_to_another_class_subject()
    {
        var first = await fixture.Api.CreateClassWithStudentAsync();
        var second = await fixture.Api.CreateClassWithStudentAsync();
        var foreignSubject = await fixture.Api.CreateSubjectAsync(second.Delegate);

        var response = await fixture.Api.As(first.Delegate).PostAsJsonAsync("/api/v1/class-resources/teachers",
            new TeacherRequest("M. Durand", null, [foreignSubject.Id]));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Choosing_a_teacher_for_a_course_links_them_to_the_subject()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();
        var subject = await fixture.Api.CreateSubjectAsync(scenario.Delegate);
        var teacher = await (await fixture.Api.As(scenario.Delegate).PostAsJsonAsync("/api/v1/class-resources/teachers",
                new TeacherRequest("Mme Leroy", null)))
            .ReadSuccessAsync<TeacherResponse>();

        var created = await fixture.Api.As(scenario.Student).PostAsJsonAsync("/api/v1/courses", new CourseRequest(
            subject.Id, teacher.Id, DateOnly.FromDateTime(DateTime.UtcNow.AddDays(3)), new TimeOnly(10, 0), new TimeOnly(11, 0), "A1"));
        await created.ReadSuccessAsync<CourseResponse>();

        var subjects = await fixture.Api.As(scenario.Student)
            .GetFromJsonAsync<SubjectResponse[]>("/api/v1/class-resources/subjects", ApiScenario.Json);
        Assert.Equal([teacher.Id], subjects!.Single(x => x.Id == subject.Id).TeacherIds);
    }
}
