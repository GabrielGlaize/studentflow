using StudyFlow.Domain.Common;

namespace StudyFlow.Domain.Apprenticeships;

public sealed class ApprenticeshipSearch : Entity
{
    public Guid UserId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Keywords { get; set; } = string.Empty;
    public string? Location { get; set; }
    public decimal? Latitude { get; set; }
    public decimal? Longitude { get; set; }
    public int? DistanceKm { get; set; }
    public string FiltersJson { get; set; } = "{}";
    public bool AlertEnabled { get; set; }
    public DateTimeOffset? LastCheckedAt { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
