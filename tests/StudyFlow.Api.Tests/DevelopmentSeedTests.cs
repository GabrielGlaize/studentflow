using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using StudyFlow.Api.Contracts;
using StudyFlow.Api.Seeding;
using StudyFlow.Api.Tests.Infrastructure;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class DevelopmentSeedTests(ApiFixture fixture)
{
    [Fact]
    public async Task The_development_seed_builds_a_usable_class_and_can_run_again()
    {
        await fixture.Api.Services.SeedDevelopmentDataAsync();
        // Deuxième passage (redémarrage de l'API) : rien n'est dupliqué.
        await fixture.Api.Services.SeedDevelopmentDataAsync();

        await using (var scope = fixture.Api.Services.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<StudyFlowDbContext>();
            var schoolClass = await db.SchoolClasses.SingleAsync(x => x.Name == DevelopmentDataSeeder.ClassName);
            Assert.Equal(8, await db.Users.CountAsync(x => x.SchoolClassId == schoolClass.Id));
            Assert.Equal(39, await db.Courses.CountAsync(x => x.SchoolClassId == schoolClass.Id));
            Assert.Equal(3, await db.StudyGroups.CountAsync(x => x.SchoolClassId == schoolClass.Id));
        }

        // Les données chiffrées se relisent par l'API, comme dans l'app.
        var login = await fixture.Api.Anonymous().PostAsJsonAsync("/api/v1/auth/login",
            new LoginRequest("gabriel@studyflow.dev", DevelopmentDataSeeder.Password));
        var gabriel = fixture.Api.As(await login.ReadSuccessAsync<AuthResponse>());
        var groups = (await gabriel.GetFromJsonAsync<StudyGroupSummaryResponse[]>("/api/v1/groups", ApiScenario.Json))!;
        Assert.Contains(groups, x => x.Status == "invited" && x.Name == "Dossier réseau");
        var team = Assert.Single(groups, x => x.Status == "active");
        Assert.Equal(2, team.UnreadCount);

        var messages = (await gabriel.GetFromJsonAsync<StudyGroupMessageResponse[]>($"/api/v1/groups/{team.Id}/messages", ApiScenario.Json))!;
        Assert.Contains(messages, x => x.Text.Contains("MCD"));

        var slots = await gabriel.GetFromJsonAsync<StudyGroupSlotsResponse>($"/api/v1/groups/{team.Id}/slots", ApiScenario.Json);
        Assert.NotEmpty(slots!.Slots);

        var exams = (await gabriel.GetFromJsonAsync<ExamSessionResponse[]>("/api/v1/exams", ApiScenario.Json))!;
        Assert.True(Assert.Single(exams).IsOpen);

        var notes = (await gabriel.GetFromJsonAsync<DailyNoteResponse[]>("/api/v1/daily-notes", ApiScenario.Json))!;
        Assert.Equal(3, notes.Length);
    }
}
