using System.Net.Http.Json;
using StudyFlow.Api.Contracts;
using StudyFlow.Api.Tests.Infrastructure;

namespace StudyFlow.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class DashboardTests(ApiFixture fixture)
{
    [Fact]
    public async Task The_dashboard_shows_the_class_of_the_student()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();
        var classInfo = await fixture.Api.As(scenario.Student)
            .GetFromJsonAsync<CurrentClassResponse>("/api/v1/classes/current", ApiScenario.Json);

        var dashboard = await fixture.Api.As(scenario.Student)
            .GetFromJsonAsync<DashboardResponse>("/api/v1/dashboard", ApiScenario.Json);

        Assert.Equal(classInfo!.Name, dashboard!.ClassName);
        Assert.Equal("2026-2027", dashboard.SchoolYear);
    }

    [Fact]
    public async Task A_student_without_class_has_no_class_name()
    {
        var session = await fixture.Api.RegisterAsync();

        var dashboard = await fixture.Api.As(session).GetFromJsonAsync<DashboardResponse>("/api/v1/dashboard", ApiScenario.Json);

        Assert.Null(dashboard!.ClassName);
    }
}
