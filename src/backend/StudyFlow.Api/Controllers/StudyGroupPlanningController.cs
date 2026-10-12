using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StudyFlow.Api.Contracts;
using StudyFlow.Api.Realtime;
using StudyFlow.Application.Groups;
using StudyFlow.Application.Security;
using StudyFlow.Application.Time;
using StudyFlow.Domain.Groups;
using StudyFlow.Infrastructure.Identity;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Api.Controllers;

/// <summary>
/// Organiser un groupe : chacun déclare une fois ses disponibilités, Swikko croise le planning
/// de la classe, les jours en entreprise et les agendas perso (seulement « occupé », jamais le
/// détail) pour proposer des créneaux communs. Une réunion proposée est confirmée quand tout
/// le monde a dit oui.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/groups")]
public sealed class StudyGroupPlanningController(
    UserManager<ApplicationUser> userManager,
    StudyFlowDbContext dbContext,
    ISensitiveDataProtector protector,
    ISchoolClock clock,
    StudyGroupNotifier notifier)
    : StudyGroupControllerBase(userManager, dbContext, protector, clock, notifier)
{
    private const string CourseDataPurpose = "course-data";
    private const string PersonalEventDataPurpose = "personal-event-data";
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    [HttpGet("availability")]
    public async Task<ActionResult<UserAvailabilityResponse>> GetAvailability(CancellationToken cancellationToken)
    {
        var availability = await Db.UserAvailabilities.AsNoTracking()
            .SingleOrDefaultAsync(x => x.UserId == CurrentUserId, cancellationToken);
        return Ok(ToResponse(availability ?? new UserAvailability { UserId = CurrentUserId }, availability is null));
    }

    [HttpPut("availability")]
    public async Task<ActionResult<UserAvailabilityResponse>> SaveAvailability(UserAvailabilityRequest request, CancellationToken cancellationToken)
    {
        if (request.AvailableUntil <= new TimeOnly(17, 0))
        {
            return BadRequestProblem("Indique jusqu'à quelle heure tu peux travailler le soir (après 17 h).");
        }

        var userId = CurrentUserId;
        var availability = await Db.UserAvailabilities.SingleOrDefaultAsync(x => x.UserId == userId, cancellationToken);
        if (availability is null)
        {
            availability = new UserAvailability { UserId = userId };
            Db.UserAvailabilities.Add(availability);
        }

        availability.CompanyEndsAt = request.CompanyEndsAt;
        availability.AvailableUntil = request.AvailableUntil;
        availability.WeekendAvailable = request.WeekendAvailable;
        availability.UsePersonalAgenda = request.UsePersonalAgenda;
        availability.UpdatedAt = Clock.UtcNow;
        await Db.SaveChangesAsync(cancellationToken);

        return Ok(ToResponse(availability, false));
    }

    /// <summary>Créneaux où tout le groupe est libre sur les <paramref name="days"/> prochains jours.</summary>
    [HttpGet("{id:guid}/slots")]
    public async Task<ActionResult<StudyGroupSlotsResponse>> Slots(
        Guid id,
        [FromQuery] int durationMinutes = 60,
        [FromQuery] int days = 14,
        CancellationToken cancellationToken = default)
    {
        var access = await AccessAsync(id, cancellationToken);
        if (access is null) return NotFound();

        durationMinutes = Math.Clamp(durationMinutes, 30, 240);
        days = Math.Clamp(days, 1, 21);
        var today = Clock.Today;
        var lastDay = today.AddDays(days - 1);
        var memberIds = ActiveMemberIds(access.Group).ToList();

        var courses = await Db.Courses.AsNoTracking()
            .Where(x => x.SchoolClassId == access.Group.SchoolClassId && x.Day >= today && x.Day <= lastDay && !x.IsCancelled)
            .Select(x => new { x.Day, x.EncryptedData })
            .ToListAsync(cancellationToken);
        var coursesByDay = courses
            .GroupBy(x => x.Day)
            .ToDictionary(x => x.Key, x => x.Select(course => ReadRange(course.EncryptedData, CourseDataPurpose)).ToList());
        var slotDays = Enumerable.Range(0, days)
            .Select(offset => today.AddDays(offset))
            .Select(day => new SlotDay(day, coursesByDay.GetValueOrDefault(day) ?? [], IsDayOff: false))
            .ToList();

        var availabilities = await Db.UserAvailabilities.AsNoTracking()
            .Where(x => memberIds.Contains(x.UserId))
            .ToDictionaryAsync(x => x.UserId, cancellationToken);
        var busy = await BusyByMemberAsync(memberIds, availabilities, today, lastDay, cancellationToken);

        var members = memberIds.Select(memberId =>
        {
            var availability = availabilities.GetValueOrDefault(memberId) ?? new UserAvailability { UserId = memberId };
            return new SlotMember(
                memberId,
                availability.CompanyEndsAt,
                availability.AvailableUntil,
                availability.WeekendAvailable,
                busy.GetValueOrDefault(memberId) ?? new Dictionary<DateOnly, IReadOnlyList<TimeRange>>());
        }).ToList();

        var slots = CommonSlotFinder.Find(slotDays, members, durationMinutes, today, Clock.CurrentTime);
        var names = await NamesAsync(memberIds, cancellationToken);

        return Ok(new StudyGroupSlotsResponse(
            durationMinutes,
            slots.Select(x => new StudyGroupSlotResponse(
                x.Day,
                x.Range.Start,
                x.Range.End,
                x.Mode == SlotMode.OnSite ? "onsite" : "remote",
                x.MissingUserIds.Select(userId => names.GetValueOrDefault(userId, "Un membre")).ToArray())).ToArray(),
            memberIds.Where(x => !availabilities.ContainsKey(x)).Select(x => names.GetValueOrDefault(x, "Un membre")).ToArray()));
    }

    [HttpGet("{id:guid}/meetings")]
    public async Task<ActionResult<IReadOnlyCollection<StudyGroupMeetingResponse>>> ListMeetings(Guid id, CancellationToken cancellationToken)
    {
        var access = await AccessAsync(id, cancellationToken);
        if (access is null) return NotFound();

        var meetings = await Db.StudyGroupMeetings.AsNoTracking()
            .Include(x => x.Votes)
            .Where(x => x.StudyGroupId == id
                && x.Status != StudyGroupMeetingStatus.Cancelled
                && x.EndsAt > Clock.UtcNow.AddDays(-7))
            .OrderBy(x => x.StartsAt)
            .ToListAsync(cancellationToken);
        var names = await NamesAsync(ActiveMemberIds(access.Group).Concat(meetings.Where(x => x.ProposedById != null).Select(x => x.ProposedById!.Value)), cancellationToken);

        return Ok(meetings.Select(x => ToResponse(x, access, names)).ToArray());
    }

    [HttpPost("{id:guid}/meetings")]
    public async Task<ActionResult<StudyGroupMeetingResponse>> ProposeMeeting(Guid id, StudyGroupMeetingRequest request, CancellationToken cancellationToken)
    {
        var access = await AccessAsync(id, cancellationToken);
        if (access is null) return NotFound();
        if (access.Group.IsArchivedAt(Clock.UtcNow)) return ArchivedProblem();

        var mode = StudyGroupMapping.ParseMeetingMode(request.Mode);
        if (mode is null) return BadRequestProblem("Choisis « sur place » ou « à distance ».");
        if (request.EndsAt <= request.StartsAt) return BadRequestProblem("La réunion doit finir après son début.");
        if (request.EndsAt - request.StartsAt > TimeSpan.FromHours(6)) return BadRequestProblem("Une réunion dure au plus 6 heures.");
        if (request.StartsAt < Clock.UtcNow.AddMinutes(-5)) return BadRequestProblem("Ce créneau est déjà passé.");

        var meeting = new StudyGroupMeeting
        {
            StudyGroupId = id,
            StartsAt = request.StartsAt.ToUniversalTime(),
            EndsAt = request.EndsAt.ToUniversalTime(),
            Mode = mode.Value,
            EncryptedPlace = ProtectOptional(request.Place, TextPurpose),
            ProposedById = access.User.Id,
            Status = StudyGroupMeetingStatus.Proposed
        };
        // Celui qui propose est forcément d'accord.
        meeting.Votes.Add(new StudyGroupMeetingVote { UserId = access.User.Id, IsAvailable = true, AnsweredAt = Clock.UtcNow });
        ConfirmIfEveryoneAgrees(meeting, access.Group);

        Db.StudyGroupMeetings.Add(meeting);
        await Db.SaveChangesAsync(cancellationToken);

        var me = StudentNames.Short(access.User.FirstName, access.User.LastName);
        var when = FormatMoment(meeting.StartsAt);
        await Notifier.SystemMessageAsync(id, $"{me} propose une réunion {when}. Réponds dans « Organiser ».", cancellationToken);
        await Notifier.ChangedAsync(id, StudyGroupNotifier.Areas.Meetings);
        await Notifier.PushAsync(id, ActiveMemberIds(access.Group).Where(x => x != access.User.Id),
            $"Réunion proposée · {access.Group.Name}", $"{me} propose {when}. Tu es dispo ?", cancellationToken);

        var names = await NamesAsync(ActiveMemberIds(access.Group), cancellationToken);
        return Ok(ToResponse(meeting, access, names));
    }

    [HttpPut("meetings/{meetingId:guid}/vote")]
    public async Task<ActionResult<StudyGroupMeetingResponse>> Vote(Guid meetingId, StudyGroupMeetingVoteRequest request, CancellationToken cancellationToken)
    {
        var meeting = await Db.StudyGroupMeetings.Include(x => x.Votes).SingleOrDefaultAsync(x => x.Id == meetingId, cancellationToken);
        if (meeting is null) return NotFound();
        var access = await AccessAsync(meeting.StudyGroupId, cancellationToken);
        if (access is null) return NotFound();
        if (meeting.Status == StudyGroupMeetingStatus.Cancelled) return BadRequestProblem("Cette réunion a été annulée.");

        var vote = meeting.Votes.SingleOrDefault(x => x.UserId == access.User.Id);
        if (vote is null)
        {
            vote = new StudyGroupMeetingVote { StudyGroupMeetingId = meeting.Id, UserId = access.User.Id };
            meeting.Votes.Add(vote);
        }

        vote.IsAvailable = request.IsAvailable;
        vote.AnsweredAt = Clock.UtcNow;
        var wasConfirmed = meeting.Status == StudyGroupMeetingStatus.Confirmed;
        if (!request.IsAvailable) meeting.Status = StudyGroupMeetingStatus.Proposed;
        ConfirmIfEveryoneAgrees(meeting, access.Group);
        meeting.UpdatedAt = Clock.UtcNow;
        await Db.SaveChangesAsync(cancellationToken);

        var when = FormatMoment(meeting.StartsAt);
        if (!wasConfirmed && meeting.Status == StudyGroupMeetingStatus.Confirmed)
        {
            await Notifier.SystemMessageAsync(meeting.StudyGroupId, $"Réunion confirmée {when} : elle est dans l'agenda de chacun.", cancellationToken);
            await Notifier.PushAsync(meeting.StudyGroupId, ActiveMemberIds(access.Group),
                $"Réunion confirmée · {access.Group.Name}", $"Tout le monde est dispo {when}.", cancellationToken);
        }
        else if (wasConfirmed && meeting.Status != StudyGroupMeetingStatus.Confirmed)
        {
            var me = StudentNames.Short(access.User.FirstName, access.User.LastName);
            await Notifier.SystemMessageAsync(meeting.StudyGroupId, $"{me} n'est plus dispo {when} : la réunion est à revoir.", cancellationToken);
        }

        await Notifier.ChangedAsync(meeting.StudyGroupId, StudyGroupNotifier.Areas.Meetings);
        var names = await NamesAsync(ActiveMemberIds(access.Group), cancellationToken);
        return Ok(ToResponse(meeting, access, names));
    }

    /// <summary>Annuler une réunion (celui qui l'a proposée ou l'organisateur).</summary>
    [HttpDelete("meetings/{meetingId:guid}")]
    public async Task<IActionResult> CancelMeeting(Guid meetingId, CancellationToken cancellationToken)
    {
        var meeting = await Db.StudyGroupMeetings.SingleOrDefaultAsync(x => x.Id == meetingId, cancellationToken);
        if (meeting is null) return NotFound();
        var access = await AccessAsync(meeting.StudyGroupId, cancellationToken);
        if (access is null) return NotFound();
        if (meeting.ProposedById != access.User.Id && !access.IsOrganizer) return Forbid();
        if (meeting.Status == StudyGroupMeetingStatus.Cancelled) return NoContent();

        meeting.Status = StudyGroupMeetingStatus.Cancelled;
        meeting.UpdatedAt = Clock.UtcNow;
        await Db.SaveChangesAsync(cancellationToken);

        var me = StudentNames.Short(access.User.FirstName, access.User.LastName);
        await Notifier.SystemMessageAsync(meeting.StudyGroupId, $"{me} a annulé la réunion {FormatMoment(meeting.StartsAt)}.", cancellationToken);
        await Notifier.ChangedAsync(meeting.StudyGroupId, StudyGroupNotifier.Areas.Meetings);
        return NoContent();
    }

    private static void ConfirmIfEveryoneAgrees(StudyGroupMeeting meeting, StudyGroup group)
    {
        var members = group.Members.Where(x => x.Status == StudyGroupMemberStatus.Active).Select(x => x.UserId).ToList();
        var yes = meeting.Votes.Where(x => x.IsAvailable).Select(x => x.UserId).ToHashSet();
        if (members.All(yes.Contains)) meeting.Status = StudyGroupMeetingStatus.Confirmed;
    }

    /// <summary>
    /// Occupations de chaque membre, par jour : ses événements perso (s'il l'accepte) et les
    /// réunions confirmées de tous ses groupes.
    /// </summary>
    private async Task<Dictionary<Guid, IReadOnlyDictionary<DateOnly, IReadOnlyList<TimeRange>>>> BusyByMemberAsync(
        IReadOnlyCollection<Guid> memberIds,
        IReadOnlyDictionary<Guid, UserAvailability> availabilities,
        DateOnly firstDay,
        DateOnly lastDay,
        CancellationToken cancellationToken)
    {
        var ranges = memberIds.ToDictionary(x => x, _ => new List<(DateOnly Day, TimeRange Range)>());

        var agendaUsers = memberIds.Where(x => availabilities.GetValueOrDefault(x)?.UsePersonalAgenda ?? true).ToArray();
        var events = await Db.PersonalEvents.AsNoTracking()
            .Where(x => agendaUsers.Contains(x.UserId) && x.Day >= firstDay && x.Day <= lastDay)
            .Select(x => new { x.UserId, x.Day, x.EncryptedData })
            .ToListAsync(cancellationToken);
        foreach (var personalEvent in events)
        {
            ranges[personalEvent.UserId].Add((personalEvent.Day, ReadRange(personalEvent.EncryptedData, PersonalEventDataPurpose)));
        }

        var from = Clock.ToSchoolTime(firstDay, TimeOnly.MinValue).ToUniversalTime();
        var to = Clock.ToSchoolTime(lastDay.AddDays(1), TimeOnly.MinValue).ToUniversalTime();
        var meetings = await Db.StudyGroupMeetings.AsNoTracking()
            .Where(x => x.Status == StudyGroupMeetingStatus.Confirmed && x.StartsAt < to && x.EndsAt > from)
            .SelectMany(x => x.Group.Members
                .Where(member => memberIds.Contains(member.UserId) && member.Status == StudyGroupMemberStatus.Active)
                .Select(member => new { member.UserId, x.StartsAt, x.EndsAt }))
            .ToListAsync(cancellationToken);
        foreach (var meeting in meetings)
        {
            var start = TimeZoneInfo.ConvertTime(meeting.StartsAt, Clock.TimeZone);
            var end = TimeZoneInfo.ConvertTime(meeting.EndsAt, Clock.TimeZone);
            var day = DateOnly.FromDateTime(start.DateTime);
            var endTime = DateOnly.FromDateTime(end.DateTime) == day ? TimeOnly.FromDateTime(end.DateTime) : TimeOnly.MaxValue;
            ranges[meeting.UserId].Add((day, new TimeRange(TimeOnly.FromDateTime(start.DateTime), endTime)));
        }

        return ranges.ToDictionary(
            x => x.Key,
            x => (IReadOnlyDictionary<DateOnly, IReadOnlyList<TimeRange>>)x.Value
                .GroupBy(range => range.Day)
                .ToDictionary(group => group.Key, group => (IReadOnlyList<TimeRange>)group.Select(range => range.Range).ToList()));
    }

    private TimeRange ReadRange(string encryptedData, string purpose)
    {
        var data = JsonSerializer.Deserialize<ProtectedTimes>(Protector.Unprotect(encryptedData, purpose), JsonOptions)!;
        return new TimeRange(data.StartsAt, data.EndsAt);
    }

    private sealed record ProtectedTimes(TimeOnly StartsAt, TimeOnly EndsAt);

    private string FormatMoment(DateTimeOffset instant)
    {
        var local = TimeZoneInfo.ConvertTime(instant, Clock.TimeZone);
        return $"{FrenchCalendar.ShortDay(DateOnly.FromDateTime(local.DateTime)).ToLowerInvariant()} à {FrenchCalendar.Time(TimeOnly.FromDateTime(local.DateTime))}";
    }

    private static UserAvailabilityResponse ToResponse(UserAvailability availability, bool isDefault) => new(
        availability.CompanyEndsAt,
        availability.AvailableUntil,
        availability.WeekendAvailable,
        availability.UsePersonalAgenda,
        isDefault);

    private StudyGroupMeetingResponse ToResponse(StudyGroupMeeting meeting, GroupAccess access, IReadOnlyDictionary<Guid, string> names)
    {
        var votes = ActiveMemberIds(access.Group)
            .Select(userId => new StudyGroupMeetingVoteResponse(
                userId,
                names.GetValueOrDefault(userId, "Un membre"),
                meeting.Votes.SingleOrDefault(x => x.UserId == userId)?.IsAvailable))
            .ToArray();

        return new StudyGroupMeetingResponse(
            meeting.Id,
            meeting.StudyGroupId,
            meeting.StartsAt,
            meeting.EndsAt,
            StudyGroupMapping.MeetingMode(meeting.Mode),
            UnprotectOptional(meeting.EncryptedPlace, TextPurpose),
            StudyGroupMapping.MeetingStatus(meeting.Status),
            meeting.ProposedById is { } proposerId ? names.GetValueOrDefault(proposerId) : null,
            meeting.ProposedById == access.User.Id || access.IsOrganizer,
            meeting.Votes.SingleOrDefault(x => x.UserId == access.User.Id)?.IsAvailable,
            votes);
    }
}
