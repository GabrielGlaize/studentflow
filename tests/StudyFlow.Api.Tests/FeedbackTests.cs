using System.Collections.Concurrent;
using System.Net;
using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using StudyFlow.Api.Contracts;
using StudyFlow.Api.Tests.Infrastructure;
using StudyFlow.Application.Support;

namespace StudyFlow.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class FeedbackTests(ApiFixture fixture)
{
    [Fact]
    public async Task An_idea_reaches_the_maintainer_by_email()
    {
        var notifier = new RecordingNotifier();
        await using var api = fixture.CreateFactory(
            configureServices: services => services.AddSingleton<IFeedbackNotifier>(notifier));
        var session = await api.RegisterAsync();

        var sent = await api.As(session).PostAsJsonAsync("/api/v1/feedback",
            new FeedbackRequest("idea", "Un mode sombre pour le planning", "1.1.0", "ios"));
        Assert.Equal(HttpStatusCode.NoContent, sent.StatusCode);

        var message = Assert.Single(notifier.Messages);
        Assert.Equal("idea", message.Kind);
        Assert.Equal(session.User.Email, message.AuthorEmail);

        var invalid = await api.As(session).PostAsJsonAsync("/api/v1/feedback",
            new FeedbackRequest("autre", "Un message"));
        Assert.Equal(HttpStatusCode.BadRequest, invalid.StatusCode);
    }

    private sealed class RecordingNotifier : IFeedbackNotifier
    {
        public ConcurrentQueue<FeedbackMessage> Messages { get; } = new();

        public Task NotifyAsync(FeedbackMessage feedback, CancellationToken cancellationToken = default)
        {
            Messages.Enqueue(feedback);
            return Task.CompletedTask;
        }
    }
}
