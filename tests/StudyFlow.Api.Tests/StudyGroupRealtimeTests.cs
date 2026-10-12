using System.Net.Http.Json;
using Microsoft.AspNetCore.Http.Connections;
using Microsoft.AspNetCore.SignalR.Client;
using StudyFlow.Api.Contracts;
using StudyFlow.Api.Tests.Infrastructure;

namespace StudyFlow.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class StudyGroupRealtimeTests(ApiFixture fixture)
{
    [Fact]
    public async Task Members_who_opened_the_group_receive_messages_instantly_and_outsiders_cannot_join()
    {
        var scenario = await fixture.Api.CreateClassWithStudentAsync();
        var group = await (await fixture.Api.As(scenario.Delegate).PostAsJsonAsync("/api/v1/groups",
                new StudyGroupRequest("Projet", InviteeIds: [scenario.Student.User.Id])))
            .ReadSuccessAsync<StudyGroupDetailResponse>();
        var groupId = group.Summary.Id;

        await using var organizer = Connect(scenario.Delegate);
        var received = new TaskCompletionSource<StudyGroupMessageResponse>(TaskCreationOptions.RunContinuationsAsynchronously);
        organizer.On<StudyGroupMessageResponse>("message", message =>
        {
            if (message.AuthorId is not null) received.TrySetResult(message);
        });
        await organizer.StartAsync();
        Assert.True(await organizer.InvokeAsync<bool>("Join", groupId));

        // Encore invité : pas de temps réel avant d'avoir accepté.
        await using var invited = Connect(scenario.Student);
        await invited.StartAsync();
        Assert.False(await invited.InvokeAsync<bool>("Join", groupId));

        await (await fixture.Api.As(scenario.Student).PostAsync($"/api/v1/groups/{groupId}/accept", null))
            .ReadSuccessAsync<StudyGroupDetailResponse>();
        await (await fixture.Api.As(scenario.Student).PostAsJsonAsync($"/api/v1/groups/{groupId}/messages",
            new StudyGroupMessageRequest("On se voit à 12 h ?"))).ReadSuccessAsync<StudyGroupMessageResponse>();

        var message = await received.Task.WaitAsync(TimeSpan.FromSeconds(10));
        Assert.Equal("On se voit à 12 h ?", message.Text);
        Assert.Equal("Liam M.", message.AuthorName);
    }

    private HubConnection Connect(AuthResponse session) =>
        new HubConnectionBuilder()
            .WithUrl(new Uri(fixture.Api.Server.BaseAddress, "hubs/groups"), options =>
            {
                options.HttpMessageHandlerFactory = _ => fixture.Api.Server.CreateHandler();
                options.Transports = HttpTransportType.LongPolling;
                options.AccessTokenProvider = () => Task.FromResult<string?>(session.Tokens.AccessToken);
            })
            .Build();
}
