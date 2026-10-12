using StudyFlow.Domain.Common;

namespace StudyFlow.Domain.Support;

/// <summary>Idée ou bug remonté depuis l'app.</summary>
public sealed class Feedback : Entity
{
    public Guid UserId { get; set; }
    public FeedbackKind Kind { get; set; }
    public string Message { get; set; } = string.Empty;
    public string? AppVersion { get; set; }
    public string? Platform { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}

public enum FeedbackKind
{
    Idea,
    Bug
}
