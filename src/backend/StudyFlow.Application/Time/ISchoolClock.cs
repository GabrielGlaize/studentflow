namespace StudyFlow.Application.Time;

/// <summary>
/// Heure de l'établissement. Les cours et événements sont saisis en heure locale
/// (Europe/Paris par défaut) : le serveur, souvent en UTC dans un conteneur, ne doit
/// jamais utiliser son propre fuseau pour décider du "prochain cours" ou d'un rappel.
/// </summary>
public interface ISchoolClock
{
    TimeZoneInfo TimeZone { get; }

    DateTimeOffset UtcNow { get; }

    /// <summary>Instant courant exprimé dans le fuseau de l'établissement.</summary>
    DateTimeOffset Now { get; }

    DateOnly Today { get; }

    TimeOnly CurrentTime { get; }

    /// <summary>Convertit un jour et une heure saisis localement en instant absolu.</summary>
    DateTimeOffset ToSchoolTime(DateOnly day, TimeOnly time);

    /// <summary>Jour local de l'établissement correspondant à un instant absolu.</summary>
    DateOnly ToSchoolDay(DateTimeOffset instant);
}
