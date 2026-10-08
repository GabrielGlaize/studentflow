using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using StudyFlow.Application.Time;

namespace StudyFlow.Infrastructure.Time;

public sealed class SchoolClock : ISchoolClock
{
    private readonly TimeProvider _timeProvider;

    public SchoolClock(TimeProvider timeProvider, IOptions<SchoolTimeOptions> options, ILogger<SchoolClock> logger)
    {
        _timeProvider = timeProvider;
        TimeZone = ResolveTimeZone(options.Value.TimeZone, logger);
    }

    public TimeZoneInfo TimeZone { get; }

    public DateTimeOffset UtcNow => _timeProvider.GetUtcNow();

    public DateTimeOffset Now => TimeZoneInfo.ConvertTime(UtcNow, TimeZone);

    public DateOnly Today => DateOnly.FromDateTime(Now.DateTime);

    public TimeOnly CurrentTime => TimeOnly.FromDateTime(Now.DateTime);

    public DateTimeOffset ToSchoolTime(DateOnly day, TimeOnly time)
    {
        var local = day.ToDateTime(time, DateTimeKind.Unspecified);

        // Au passage à l'heure d'été, 02:30 n'existe pas : on prend l'heure qui suit.
        if (TimeZone.IsInvalidTime(local))
        {
            local = local.AddHours(1);
        }

        return new DateTimeOffset(local, TimeZone.GetUtcOffset(local));
    }

    public DateOnly ToSchoolDay(DateTimeOffset instant) =>
        DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(instant, TimeZone).DateTime);

    private static TimeZoneInfo ResolveTimeZone(string timeZoneId, ILogger logger)
    {
        try
        {
            return TimeZoneInfo.FindSystemTimeZoneById(timeZoneId);
        }
        catch (Exception exception) when (exception is TimeZoneNotFoundException or InvalidTimeZoneException)
        {
            // Une image Docker sans tzdata ne connaît pas Europe/Paris : on le signale fort,
            // sans empêcher l'API de démarrer.
            logger.LogError(
                exception,
                "Fuseau horaire {TimeZoneId} introuvable (paquet tzdata absent ?). Le fuseau du serveur est utilisé à la place.",
                timeZoneId);
            return TimeZoneInfo.Local;
        }
    }
}
