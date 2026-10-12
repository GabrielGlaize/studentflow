namespace StudyFlow.Application.Groups;

/// <summary>Plage horaire locale d'une journée.</summary>
public readonly record struct TimeRange(TimeOnly Start, TimeOnly End)
{
    public int Minutes => (int)(End - Start).TotalMinutes;
}

public enum SlotMode
{
    OnSite,
    Remote
}

/// <summary>Une journée vue par la classe : ses cours (non annulés), et si c'est un jour sans école possible.</summary>
public sealed record SlotDay(DateOnly Day, IReadOnlyList<TimeRange> ClassCourses, bool IsDayOff);

/// <summary>Contraintes d'un membre : ses disponibilités déclarées et ses occupations perso, par jour.</summary>
public sealed record SlotMember(
    Guid UserId,
    TimeOnly CompanyEndsAt,
    TimeOnly AvailableUntil,
    bool WeekendAvailable,
    IReadOnlyDictionary<DateOnly, IReadOnlyList<TimeRange>> Busy);

public sealed record CommonSlot(DateOnly Day, TimeRange Range, SlotMode Mode, IReadOnlyList<Guid> MissingUserIds);

/// <summary>
/// Cherche les moments où tout le groupe est libre, en croisant le planning de la classe,
/// les jours en entreprise et les occupations de chacun :
/// <list type="bullet">
/// <item>jour de cours : tout le monde est à l'école, les pauses et la fin de journée se font
/// sur place ; plus tard dans la soirée, à distance ;</item>
/// <item>jour de semaine sans cours : jour en entreprise, libre seulement après le travail et
/// le trajet, à distance ;</item>
/// <item>week-end et jours fériés : à distance, si chacun l'accepte.</item>
/// </list>
/// Sans créneau commun, il propose ceux où il ne manque qu'une personne (groupe de 3 ou plus).
/// </summary>
public static class CommonSlotFinder
{
    public static readonly TimeOnly EarliestStart = new(8, 0);
    public static readonly TimeOnly WeekendStart = new(10, 0);

    /// <summary>On reste sur place au plus 1 h 30 après le dernier cours.</summary>
    public const int OnSiteAfterClassMinutes = 90;

    /// <summary>Temps pour rentrer chez soi, de l'école ou de l'entreprise.</summary>
    public const int TravelMinutes = 45;

    public const int MaxSlots = 12;

    public static IReadOnlyList<CommonSlot> Find(
        IReadOnlyList<SlotDay> days,
        IReadOnlyList<SlotMember> members,
        int durationMinutes,
        DateOnly today,
        TimeOnly nowTime)
    {
        if (members.Count == 0 || durationMinutes <= 0) return [];

        var full = FindFor(days, members, durationMinutes, today, nowTime, missing: null);
        if (full.Count > 0 || members.Count < 3) return full.Take(MaxSlots).ToList();

        // Personne n'est libre en même temps : on cherche sans chacun des membres, tour à tour.
        return members
            .SelectMany(absent => FindFor(
                days,
                members.Where(x => x.UserId != absent.UserId).ToList(),
                durationMinutes,
                today,
                nowTime,
                missing: absent.UserId))
            .OrderBy(x => x.Day)
            .ThenBy(x => x.Range.Start)
            .Take(MaxSlots)
            .ToList();
    }

    private static List<CommonSlot> FindFor(
        IReadOnlyList<SlotDay> days,
        IReadOnlyList<SlotMember> members,
        int durationMinutes,
        DateOnly today,
        TimeOnly nowTime,
        Guid? missing)
    {
        var slots = new List<CommonSlot>();
        IReadOnlyList<Guid> missingIds = missing is { } id ? [id] : [];
        var dayEnd = members.Min(x => x.AvailableUntil);

        foreach (var day in days.OrderBy(x => x.Day))
        {
            if (day.Day < today) continue;

            var isWeekend = day.Day.DayOfWeek is DayOfWeek.Saturday or DayOfWeek.Sunday;
            var courses = day.ClassCourses.OrderBy(x => x.Start).ToList();
            var windows = new List<(TimeRange Range, SlotMode Mode)>();

            if (courses.Count > 0)
            {
                var firstStart = courses[0].Start;
                var lastEnd = courses.Max(x => x.End);
                var onSiteEnd = Min(lastEnd.AddMinutes(OnSiteAfterClassMinutes), dayEnd);
                if (onSiteEnd > firstStart) windows.Add((new TimeRange(firstStart, onSiteEnd), SlotMode.OnSite));

                var remoteStart = lastEnd.AddMinutes(OnSiteAfterClassMinutes + TravelMinutes);
                if (remoteStart > lastEnd && remoteStart < dayEnd) windows.Add((new TimeRange(remoteStart, dayEnd), SlotMode.Remote));
            }
            else if (isWeekend || day.IsDayOff)
            {
                if (!members.All(x => x.WeekendAvailable)) continue;
                if (dayEnd > WeekendStart) windows.Add((new TimeRange(WeekendStart, dayEnd), SlotMode.Remote));
            }
            else
            {
                // Jour en entreprise : chacun est libre après son travail et son trajet.
                var start = members.Max(x => x.CompanyEndsAt).AddMinutes(TravelMinutes);
                if (start > EarliestStart && start < dayEnd) windows.Add((new TimeRange(start, dayEnd), SlotMode.Remote));
            }

            var busy = courses
                .Concat(members.SelectMany(x => x.Busy.TryGetValue(day.Day, out var ranges) ? ranges : []))
                .ToList();
            if (day.Day == today)
            {
                // Aujourd'hui : rien avant une demi-heure, le temps de prévenir tout le monde.
                var cutoff = nowTime.AddMinutes(30);
                if (cutoff < nowTime) continue;
                busy.Add(new TimeRange(TimeOnly.MinValue, cutoff));
            }

            foreach (var (window, mode) in windows)
            {
                foreach (var free in Subtract(window, busy))
                {
                    if (free.Minutes >= durationMinutes) slots.Add(new CommonSlot(day.Day, free, mode, missingIds));
                }
            }
        }

        return slots;
    }

    /// <summary>Retire d'une plage toutes les occupations qui la chevauchent.</summary>
    public static IReadOnlyList<TimeRange> Subtract(TimeRange window, IEnumerable<TimeRange> busy)
    {
        var free = new List<TimeRange>();
        var cursor = window.Start;
        foreach (var range in busy.Where(x => x.End > window.Start && x.Start < window.End).OrderBy(x => x.Start))
        {
            if (range.Start > cursor) free.Add(new TimeRange(cursor, range.Start));
            if (range.End > cursor) cursor = range.End;
            if (cursor >= window.End) break;
        }

        if (cursor < window.End) free.Add(new TimeRange(cursor, window.End));
        return free;
    }

    private static TimeOnly Min(TimeOnly first, TimeOnly second) => first < second ? first : second;
}
