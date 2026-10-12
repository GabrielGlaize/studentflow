namespace StudyFlow.Application.Support;

/// <summary>Prévient le responsable de l'app qu'une idée ou un bug a été remonté.</summary>
public interface IFeedbackNotifier
{
    Task NotifyAsync(FeedbackMessage feedback, CancellationToken cancellationToken = default);
}

public sealed record FeedbackMessage(
    string Kind,
    string Message,
    string AuthorName,
    string AuthorEmail,
    string? AppVersion,
    string? Platform);
