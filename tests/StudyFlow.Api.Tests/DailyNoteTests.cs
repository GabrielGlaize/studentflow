using System.Net;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using StudyFlow.Api.Contracts;
using StudyFlow.Api.Tests.Infrastructure;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class DailyNoteTests(ApiFixture fixture)
{
    [Fact]
    public async Task A_daily_note_is_encrypted_private_and_the_latest_version_wins()
    {
        var owner = await fixture.Api.RegisterAsync();
        var client = fixture.Api.As(owner);
        var day = DateOnly.FromDateTime(DateTime.UtcNow);
        var now = DateTimeOffset.UtcNow;

        var saved = await (await client.PutAsJsonAsync($"/api/v1/daily-notes/{day:yyyy-MM-dd}",
                new DailyNoteRequest("14:02 · Rendre le badge", now)))
            .ReadSuccessAsync<DailyNoteResponse>();
        Assert.Equal("14:02 · Rendre le badge", saved.Text);

        await using (var scope = fixture.Api.Services.CreateAsyncScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<StudyFlowDbContext>();
            var stored = await dbContext.DailyNotes.SingleAsync(x => x.UserId == owner.User.Id);
            Assert.DoesNotContain("badge", stored.EncryptedText, StringComparison.OrdinalIgnoreCase);
        }

        // Une modification plus ancienne (autre appareil hors ligne) ne remplace rien.
        var stale = await (await client.PutAsJsonAsync($"/api/v1/daily-notes/{day:yyyy-MM-dd}",
                new DailyNoteRequest("ancienne version", now.AddMinutes(-5))))
            .ReadSuccessAsync<DailyNoteResponse>();
        Assert.Equal("14:02 · Rendre le badge", stale.Text);

        var other = fixture.Api.As(await fixture.Api.RegisterAsync());
        Assert.Empty((await other.GetFromJsonAsync<DailyNoteResponse[]>("/api/v1/daily-notes", ApiScenario.Json))!);

        var cleared = await client.PutAsJsonAsync($"/api/v1/daily-notes/{day:yyyy-MM-dd}",
            new DailyNoteRequest("", now.AddMinutes(1)));
        Assert.Equal(HttpStatusCode.NoContent, cleared.StatusCode);
        Assert.Empty((await client.GetFromJsonAsync<DailyNoteResponse[]>("/api/v1/daily-notes", ApiScenario.Json))!);
    }
}
