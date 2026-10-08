using System.Net;
using System.Net.Http.Json;
using StudyFlow.Api.Contracts;
using StudyFlow.Api.Tests.Infrastructure;

namespace StudyFlow.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class ClassAccessTests(ApiFixture fixture)
{
    [Fact]
    public async Task A_student_cannot_read_the_courses_of_another_class()
    {
        var classA = await fixture.Api.CreateClassWithStudentAsync();
        var classB = await fixture.Api.CreateClassWithStudentAsync();
        var course = await CreateCourseAsync(classB.Delegate);

        var studentA = fixture.Api.As(classA.Student);
        var direct = await studentA.GetAsync($"/api/v1/courses/{course.Id}");
        Assert.Equal(HttpStatusCode.NotFound, direct.StatusCode);

        var list = await studentA.GetFromJsonAsync<CourseResponse[]>(
            $"/api/v1/courses?from={course.Day:yyyy-MM-dd}&to={course.Day:yyyy-MM-dd}", ApiScenario.Json);
        Assert.DoesNotContain(list!, x => x.Id == course.Id);
    }

    [Fact]
    public async Task A_pending_member_has_no_access_to_school_data()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();
        var pending = await fixture.Api.RegisterAsync();
        var join = await fixture.Api.As(pending).PostAsJsonAsync("/api/v1/classes/join", new JoinClassRequest(scenario.ClassCode));
        Assert.Equal(HttpStatusCode.Created, join.StatusCode);

        var courses = await fixture.Api.As(pending).GetAsync("/api/v1/courses");
        Assert.Equal(HttpStatusCode.Forbidden, courses.StatusCode);
    }

    [Fact]
    public async Task Only_delegates_manage_subjects_and_teachers()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();
        var student = fixture.Api.As(scenario.Student);

        var subject = await student.PostAsJsonAsync("/api/v1/class-resources/subjects", new SubjectRequest("Anglais"));
        Assert.Equal(HttpStatusCode.Forbidden, subject.StatusCode);

        var teacher = await student.PostAsJsonAsync("/api/v1/class-resources/teachers", new TeacherRequest("M. Dupont", null));
        Assert.Equal(HttpStatusCode.Forbidden, teacher.StatusCode);

        // La lecture reste ouverte à toute la classe.
        var created = await fixture.Api.CreateSubjectAsync(scenario.Delegate);
        var subjects = await student.GetFromJsonAsync<SubjectResponse[]>("/api/v1/class-resources/subjects", ApiScenario.Json);
        Assert.Contains(subjects!, x => x.Id == created.Id);
    }

    [Fact]
    public async Task Member_emails_are_only_visible_to_delegates()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();

        var seenByStudent = await fixture.Api.As(scenario.Student)
            .GetFromJsonAsync<ClassMemberResponse[]>("/api/v1/classes/current/members", ApiScenario.Json);
        Assert.All(seenByStudent!, member => Assert.Null(member.Email));
        Assert.Contains(seenByStudent!, member => member.IsDelegate);

        var seenByDelegate = await fixture.Api.As(scenario.Delegate)
            .GetFromJsonAsync<ClassMemberResponse[]>("/api/v1/classes/current/members", ApiScenario.Json);
        Assert.Contains(seenByDelegate!, member => member.Email == scenario.StudentEmail);
    }

    [Fact]
    public async Task The_class_code_cannot_be_brute_forced()
    {
        await using var api = fixture.CreateFactory(new Dictionary<string, string?>
        {
            ["RateLimiting:ClassJoin:PermitLimit"] = "3"
        });
        var user = api.As(await api.RegisterAsync());

        for (var attempt = 0; attempt < 3; attempt++)
        {
            var wrong = await user.PostAsJsonAsync("/api/v1/classes/join", new JoinClassRequest("AAAA-AAAA"));
            Assert.Equal(HttpStatusCode.NotFound, wrong.StatusCode);
        }

        var limited = await user.PostAsJsonAsync("/api/v1/classes/join", new JoinClassRequest("AAAA-AAAA"));
        Assert.Equal(HttpStatusCode.TooManyRequests, limited.StatusCode);
    }

    private async Task<CourseResponse> CreateCourseAsync(AuthResponse delegateSession)
    {
        var subject = await fixture.Api.CreateSubjectAsync(delegateSession);
        var response = await fixture.Api.As(delegateSession).PostAsJsonAsync("/api/v1/courses", new CourseRequest(
            subject.Id, null, new DateOnly(2026, 11, 2), new TimeOnly(9, 0), new TimeOnly(10, 0), "B204"));
        return await response.ReadSuccessAsync<CourseResponse>();
    }
}
