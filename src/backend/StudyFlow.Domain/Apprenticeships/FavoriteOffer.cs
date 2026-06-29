using StudyFlow.Domain.Common;

namespace StudyFlow.Domain.Apprenticeships;

public sealed class FavoriteOffer : Entity
{
    public Guid UserId { get; set; }
    public string Source { get; set; } = string.Empty;
    public string ExternalOfferId { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string? Company { get; set; }
    public string? Location { get; set; }
    public string Url { get; set; } = string.Empty;
    public DateTimeOffset? PublishedAt { get; set; }
    public DateTimeOffset SavedAt { get; set; } = DateTimeOffset.UtcNow;
}
