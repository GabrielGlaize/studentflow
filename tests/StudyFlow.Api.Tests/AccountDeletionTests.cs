using System.Net;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using StudyFlow.Api.Contracts;
using StudyFlow.Api.Tests.Infrastructure;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class AccountDeletionTests(ApiFixture fixture)
{
    [Fact]
    public async Task Deleting_an_account_erases_personal_data_and_frees_the_email()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();
        var student = fixture.Api.As(scenario.Student);
        var task = await student.PostAsJsonAsync("/api/v1/personal-agenda/tasks",
            new PersonalTaskRequest("Relancer l'entreprise", null, null, "apprenticeship"));
        Assert.Equal(HttpStatusCode.Created, task.StatusCode);

        var deleted = await student.DeleteAsync("/api/v1/auth/me");
        Assert.Equal(HttpStatusCode.NoContent, deleted.StatusCode);

        await using (var scope = fixture.Api.Services.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<StudyFlowDbContext>();
            var user = await dbContext.Users.SingleAsync(x => x.Id == scenario.Student.User.Id);
            Assert.False(user.IsActive);
            Assert.NotEqual(scenario.StudentEmail, user.Email);
            Assert.Null(user.PasswordHash);
            Assert.Equal("Compte", user.FirstName);
            Assert.False(await dbContext.PersonalTasks.AnyAsync(x => x.UserId == user.Id));
            Assert.False(await dbContext.RefreshTokens.AnyAsync(x => x.UserId == user.Id));
        }

        // L'ancien access token est révoqué et l'adresse peut servir à un nouveau compte.
        Assert.Equal(HttpStatusCode.Unauthorized, (await student.GetAsync("/api/v1/auth/me")).StatusCode);
        await fixture.Api.RegisterAsync(scenario.StudentEmail);
    }

    [Fact]
    public async Task The_last_delegate_of_a_class_with_members_cannot_delete_the_account()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();

        var response = await fixture.Api.As(scenario.Delegate).DeleteAsync("/api/v1/auth/me");

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }

    [Fact]
    public async Task Class_content_stays_with_an_anonymous_author()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();
        var delegateClient = fixture.Api.As(scenario.Delegate);
        var announcement = await delegateClient.PostAsJsonAsync("/api/v1/class-announcements",
            new ClassAnnouncementRequest("Sortie au musée vendredi", IsPinned: true));
        Assert.Equal(HttpStatusCode.Created, announcement.StatusCode);

        // Le délégué transmet son rôle puis supprime son compte.
        var promote = await delegateClient.PostAsync(
            $"/api/v1/classes/current/members/{scenario.Student.User.Id}/make-delegate", null);
        Assert.Equal(HttpStatusCode.NoContent, promote.StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await delegateClient.DeleteAsync("/api/v1/auth/me")).StatusCode);

        var newDelegate = await fixture.Api.LoginAsync(scenario.StudentEmail);
        var announcements = await fixture.Api.As(newDelegate)
            .GetFromJsonAsync<ClassAnnouncementResponse[]>("/api/v1/class-announcements", ApiScenario.Json);

        var kept = Assert.Single(announcements!);
        Assert.Equal("Compte supprimé", kept.AuthorName);
    }
}
