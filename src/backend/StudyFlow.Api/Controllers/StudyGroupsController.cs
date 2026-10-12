using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StudyFlow.Api.Contracts;
using StudyFlow.Api.Realtime;
using StudyFlow.Application.Security;
using StudyFlow.Application.Time;
using StudyFlow.Domain.Groups;
using StudyFlow.Infrastructure.Identity;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Api.Controllers;

/// <summary>
/// Groupes de travail : un élève crée un groupe privé (rattaché ou non à un devoir et à un
/// cours), invite des camarades de sa classe et l'organise. L'organisateur invite, retire et
/// peut passer la main ; chacun peut se donner un rôle libre.
/// Pour un même devoir, un élève n'est que dans un seul groupe.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/groups")]
public sealed class StudyGroupsController(
    UserManager<ApplicationUser> userManager,
    StudyFlowDbContext dbContext,
    ISensitiveDataProtector protector,
    ISchoolClock clock,
    StudyGroupNotifier notifier)
    : StudyGroupControllerBase(userManager, dbContext, protector, clock, notifier)
{
    /// <summary>Mes groupes et les invitations reçues, les plus actifs en premier.</summary>
    [HttpGet]
    public async Task<ActionResult<IReadOnlyCollection<StudyGroupSummaryResponse>>> List(CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Ok(Array.Empty<StudyGroupSummaryResponse>());

        var groups = await Db.StudyGroups
            .AsNoTracking()
            .Include(x => x.Members)
            .Include(x => x.Homework)
            .Include(x => x.Subject)
            .AsSplitQuery()
            .Where(x => x.SchoolClassId == user.SchoolClassId && x.Members.Any(member => member.UserId == user.Id))
            .ToListAsync(cancellationToken);

        var summaries = await SummariesAsync(groups, user.Id, cancellationToken);
        return Ok(summaries
            .OrderBy(x => x.Status == "invited" ? 0 : 1)
            .ThenBy(x => x.IsArchived)
            .ThenByDescending(x => x.LastActivityAt ?? DateTimeOffset.MinValue)
            .ToArray());
    }

    [HttpPost]
    public async Task<ActionResult<StudyGroupDetailResponse>> Create(StudyGroupRequest request, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();
        var classId = user.SchoolClassId.Value;

        var name = Clean(request.Name);
        if (name is null) return BadRequestProblem("Donne un nom au groupe (ex. Projet BDD — équipe 2).");

        var links = await ResolveLinksAsync(classId, request, cancellationToken);
        if (links.Problem is not null) return links.Problem;

        if (links.HomeworkId is { } homeworkId && await IsInGroupForHomeworkAsync(user.Id, homeworkId, null, cancellationToken))
        {
            return ConflictProblem("Tu es déjà dans un groupe pour ce devoir.");
        }

        var group = new StudyGroup
        {
            SchoolClassId = classId,
            Name = name,
            EncryptedDescription = ProtectOptional(request.Description, TextPurpose),
            SubjectId = links.SubjectId,
            HomeworkId = links.HomeworkId,
            DueAt = links.DueAt,
            CreatedById = user.Id
        };
        group.Members.Add(new StudyGroupMember
        {
            UserId = user.Id,
            Role = StudyGroupRole.Organizer,
            Status = StudyGroupMemberStatus.Active,
            JoinedAt = Clock.UtcNow,
            LastReadAt = Clock.UtcNow
        });

        var invitees = await ValidInviteesAsync(group, request.InviteeIds ?? [], user.Id, cancellationToken);
        if (invitees.Problem is not null) return invitees.Problem;
        foreach (var inviteeId in invitees.UserIds) group.Members.Add(NewInvitation(inviteeId, user.Id));

        Db.StudyGroups.Add(group);
        await Db.SaveChangesAsync(cancellationToken);

        await Notifier.SystemMessageAsync(group.Id, $"{StudentNames.Short(user.FirstName, user.LastName)} a créé le groupe.", cancellationToken);
        await NotifyInvitationAsync(group, invitees.UserIds, user, cancellationToken);

        return CreatedAtAction(nameof(Get), new { id = group.Id }, await DetailAsync(group.Id, user.Id, cancellationToken));
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<StudyGroupDetailResponse>> Get(Guid id, CancellationToken cancellationToken)
    {
        var access = await AccessAsync(id, cancellationToken, allowInvited: true);
        if (access is null) return NotFound();

        return Ok(await DetailAsync(id, access.User.Id, cancellationToken));
    }

    [HttpPut("{id:guid}")]
    public async Task<ActionResult<StudyGroupDetailResponse>> Update(Guid id, StudyGroupRequest request, CancellationToken cancellationToken)
    {
        var access = await AccessAsync(id, cancellationToken);
        if (access is null) return NotFound();
        if (!access.IsOrganizer) return Forbid();

        var name = Clean(request.Name);
        if (name is null) return BadRequestProblem("Donne un nom au groupe.");

        var links = await ResolveLinksAsync(access.Group.SchoolClassId, request, cancellationToken);
        if (links.Problem is not null) return links.Problem;

        if (links.HomeworkId is { } homeworkId && homeworkId != access.Group.HomeworkId)
        {
            foreach (var memberId in access.Group.Members.Select(x => x.UserId))
            {
                if (await IsInGroupForHomeworkAsync(memberId, homeworkId, access.Group.Id, cancellationToken))
                {
                    return ConflictProblem("Un membre du groupe est déjà dans un autre groupe pour ce devoir.");
                }
            }
        }

        var group = access.Group;
        group.Name = name;
        group.EncryptedDescription = ProtectOptional(request.Description, TextPurpose);
        group.SubjectId = links.SubjectId;
        group.HomeworkId = links.HomeworkId;
        group.DueAt = links.DueAt;
        group.UpdatedAt = Clock.UtcNow;
        await Db.SaveChangesAsync(cancellationToken);
        await Notifier.ChangedAsync(group.Id, StudyGroupNotifier.Areas.Group);

        return Ok(await DetailAsync(group.Id, access.User.Id, cancellationToken));
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken cancellationToken)
    {
        var access = await AccessAsync(id, cancellationToken);
        if (access is null) return NotFound();
        if (!access.IsOrganizer) return Forbid();

        Db.StudyGroups.Remove(access.Group);
        await Db.SaveChangesAsync(cancellationToken);
        await Notifier.ChangedAsync(id, StudyGroupNotifier.Areas.Group);
        return NoContent();
    }

    [HttpPost("{id:guid}/invitations")]
    public async Task<ActionResult<StudyGroupDetailResponse>> Invite(Guid id, StudyGroupInviteRequest request, CancellationToken cancellationToken)
    {
        var access = await AccessAsync(id, cancellationToken);
        if (access is null) return NotFound();
        if (!access.IsOrganizer) return Forbid();
        if (access.Group.IsArchivedAt(Clock.UtcNow)) return ArchivedProblem();

        var invitees = await ValidInviteesAsync(access.Group, request.UserIds, access.User.Id, cancellationToken);
        if (invitees.Problem is not null) return invitees.Problem;
        if (invitees.UserIds.Count == 0) return BadRequestProblem("Choisis au moins un camarade à inviter.");

        foreach (var inviteeId in invitees.UserIds)
        {
            Db.StudyGroupMembers.Add(NewInvitation(inviteeId, access.User.Id, access.Group.Id));
        }

        await Db.SaveChangesAsync(cancellationToken);
        await NotifyInvitationAsync(access.Group, invitees.UserIds, access.User, cancellationToken);
        await Notifier.ChangedAsync(id, StudyGroupNotifier.Areas.Members);

        return Ok(await DetailAsync(id, access.User.Id, cancellationToken));
    }

    [HttpPost("{id:guid}/accept")]
    public async Task<ActionResult<StudyGroupDetailResponse>> Accept(Guid id, CancellationToken cancellationToken)
    {
        var access = await AccessAsync(id, cancellationToken, allowInvited: true);
        if (access is null) return NotFound();
        if (access.Member.Status == StudyGroupMemberStatus.Active) return Ok(await DetailAsync(id, access.User.Id, cancellationToken));

        if (access.Group.HomeworkId is { } homeworkId)
        {
            if (await IsInGroupForHomeworkAsync(access.User.Id, homeworkId, id, cancellationToken))
            {
                return ConflictProblem("Tu es déjà dans un autre groupe pour ce devoir. Quitte-le d'abord.");
            }

            // Un seul groupe par devoir : les autres invitations pour ce devoir tombent.
            await Db.StudyGroupMembers
                .Where(x => x.UserId == access.User.Id
                    && x.Status == StudyGroupMemberStatus.Invited
                    && x.StudyGroupId != id
                    && x.Group.HomeworkId == homeworkId)
                .ExecuteDeleteAsync(cancellationToken);
        }

        access.Member.Status = StudyGroupMemberStatus.Active;
        access.Member.JoinedAt = Clock.UtcNow;
        access.Member.LastReadAt = Clock.UtcNow;
        await Db.SaveChangesAsync(cancellationToken);

        await Notifier.SystemMessageAsync(id, $"{StudentNames.Short(access.User.FirstName, access.User.LastName)} a rejoint le groupe.", cancellationToken);
        await Notifier.ChangedAsync(id, StudyGroupNotifier.Areas.Members);
        return Ok(await DetailAsync(id, access.User.Id, cancellationToken));
    }

    [HttpPost("{id:guid}/decline")]
    public async Task<IActionResult> Decline(Guid id, CancellationToken cancellationToken)
    {
        var access = await AccessAsync(id, cancellationToken, allowInvited: true);
        if (access is null) return NotFound();
        if (access.Member.Status != StudyGroupMemberStatus.Invited) return BadRequestProblem("Tu fais déjà partie de ce groupe.");

        Db.StudyGroupMembers.Remove(access.Member);
        await Db.SaveChangesAsync(cancellationToken);
        await Notifier.ChangedAsync(id, StudyGroupNotifier.Areas.Members);
        return NoContent();
    }

    /// <summary>
    /// Quitter le groupe. L'organisateur passe la main au membre le plus ancien ; le dernier
    /// membre qui part emporte le groupe.
    /// </summary>
    [HttpPost("{id:guid}/leave")]
    public async Task<IActionResult> Leave(Guid id, CancellationToken cancellationToken)
    {
        var access = await AccessAsync(id, cancellationToken);
        if (access is null) return NotFound();

        var group = access.Group;
        var others = group.Members
            .Where(x => x.UserId != access.User.Id && x.Status == StudyGroupMemberStatus.Active)
            .OrderBy(x => x.JoinedAt)
            .ToList();
        if (others.Count == 0)
        {
            Db.StudyGroups.Remove(group);
            await Db.SaveChangesAsync(cancellationToken);
            return NoContent();
        }

        var name = StudentNames.Short(access.User.FirstName, access.User.LastName);
        string? successor = null;
        if (access.IsOrganizer)
        {
            others[0].Role = StudyGroupRole.Organizer;
            successor = (await NamesAsync([others[0].UserId], cancellationToken)).GetValueOrDefault(others[0].UserId);
        }

        await RemoveMemberAsync(group, access.Member, cancellationToken);
        await Notifier.SystemMessageAsync(id,
            successor is null ? $"{name} a quitté le groupe." : $"{name} a quitté le groupe. {successor} l'organise maintenant.",
            cancellationToken);
        return NoContent();
    }

    /// <summary>Retirer un membre, ou annuler une invitation (organisateur).</summary>
    [HttpDelete("{id:guid}/members/{userId:guid}")]
    public async Task<IActionResult> RemoveMember(Guid id, Guid userId, CancellationToken cancellationToken)
    {
        var access = await AccessAsync(id, cancellationToken);
        if (access is null) return NotFound();
        if (!access.IsOrganizer) return Forbid();
        if (userId == access.User.Id) return BadRequestProblem("Pour partir, utilise « Quitter le groupe ».");

        var member = access.Group.Members.SingleOrDefault(x => x.UserId == userId);
        if (member is null) return NotFound();

        var wasActive = member.Status == StudyGroupMemberStatus.Active;
        await RemoveMemberAsync(access.Group, member, cancellationToken);
        if (wasActive)
        {
            var name = (await NamesAsync([userId], cancellationToken)).GetValueOrDefault(userId, "Un membre");
            await Notifier.SystemMessageAsync(id, $"{name} a été retiré du groupe.", cancellationToken);
        }

        return NoContent();
    }

    [HttpPut("{id:guid}/members/{userId:guid}/organizer")]
    public async Task<ActionResult<StudyGroupDetailResponse>> MakeOrganizer(Guid id, Guid userId, CancellationToken cancellationToken)
    {
        var access = await AccessAsync(id, cancellationToken);
        if (access is null) return NotFound();
        if (!access.IsOrganizer) return Forbid();

        var target = access.Group.Members.SingleOrDefault(x => x.UserId == userId && x.Status == StudyGroupMemberStatus.Active);
        if (target is null) return NotFound();
        if (target.UserId == access.User.Id) return Ok(await DetailAsync(id, access.User.Id, cancellationToken));

        target.Role = StudyGroupRole.Organizer;
        access.Member.Role = StudyGroupRole.Member;
        await Db.SaveChangesAsync(cancellationToken);

        var name = (await NamesAsync([userId], cancellationToken)).GetValueOrDefault(userId, "Un membre");
        await Notifier.SystemMessageAsync(id, $"{name} organise maintenant le groupe.", cancellationToken);
        await Notifier.ChangedAsync(id, StudyGroupNotifier.Areas.Members);
        return Ok(await DetailAsync(id, access.User.Id, cancellationToken));
    }

    /// <summary>Mon rôle dans le groupe (« Rédaction », « Diapos »…), ou vide pour l'effacer.</summary>
    [HttpPut("{id:guid}/me/role")]
    public async Task<ActionResult<StudyGroupDetailResponse>> SetMyRole(Guid id, StudyGroupRoleLabelRequest request, CancellationToken cancellationToken)
    {
        var access = await AccessAsync(id, cancellationToken);
        if (access is null) return NotFound();

        access.Member.RoleLabel = Clean(request.RoleLabel);
        await Db.SaveChangesAsync(cancellationToken);
        await Notifier.ChangedAsync(id, StudyGroupNotifier.Areas.Members);
        return Ok(await DetailAsync(id, access.User.Id, cancellationToken));
    }

    /// <summary>Camarades de classe à inviter, avec le groupe qu'ils ont déjà pour ce devoir.</summary>
    [HttpGet("classmates")]
    public async Task<ActionResult<IReadOnlyCollection<StudyGroupClassmateResponse>>> Classmates(
        [FromQuery] Guid? homeworkId,
        [FromQuery] Guid? groupId,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var classmates = await Db.Users.AsNoTracking()
            .Where(x => x.SchoolClassId == user.SchoolClassId && x.IsActive && x.Id != user.Id)
            .OrderBy(x => x.FirstName).ThenBy(x => x.LastName)
            .Select(x => new { x.Id, x.FirstName, x.LastName })
            .ToListAsync(cancellationToken);

        var groupByUser = new Dictionary<Guid, string>();
        if (homeworkId is { } linkedHomeworkId)
        {
            groupByUser = (await Db.StudyGroupMembers.AsNoTracking()
                    .Where(x => x.Status == StudyGroupMemberStatus.Active
                        && x.Group.HomeworkId == linkedHomeworkId
                        && x.Group.SchoolClassId == user.SchoolClassId)
                    .Select(x => new { x.UserId, x.Group.Name })
                    .ToListAsync(cancellationToken))
                .GroupBy(x => x.UserId)
                .ToDictionary(x => x.Key, x => x.First().Name);
        }

        var inGroup = groupId is { } currentGroupId
            ? (await Db.StudyGroupMembers.AsNoTracking()
                .Where(x => x.StudyGroupId == currentGroupId && x.Group.SchoolClassId == user.SchoolClassId)
                .Select(x => x.UserId)
                .ToListAsync(cancellationToken)).ToHashSet()
            : [];

        return Ok(classmates.Select(x => new StudyGroupClassmateResponse(
            x.Id,
            StudentNames.Short(x.FirstName, x.LastName),
            groupByUser.GetValueOrDefault(x.Id),
            inGroup.Contains(x.Id))).ToArray());
    }

    /// <summary>
    /// Pour un devoir de groupe : quels groupes existent et qui n'en a pas encore, pour que
    /// personne ne reste seul. Le contenu des groupes reste privé.
    /// </summary>
    [HttpGet("homework/{homeworkId:guid}/overview")]
    public async Task<ActionResult<StudyGroupHomeworkOverviewResponse>> HomeworkOverview(Guid homeworkId, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var homeworkExists = await Db.HomeworkItems.AnyAsync(x => x.Id == homeworkId && x.SchoolClassId == user.SchoolClassId, cancellationToken);
        if (!homeworkExists) return NotFound();

        var groups = await Db.StudyGroups.AsNoTracking()
            .Include(x => x.Members)
            .Where(x => x.SchoolClassId == user.SchoolClassId && x.HomeworkId == homeworkId)
            .OrderBy(x => x.CreatedAt)
            .ToListAsync(cancellationToken);
        var students = await Db.Users.AsNoTracking()
            .Where(x => x.SchoolClassId == user.SchoolClassId && x.IsActive)
            .OrderBy(x => x.FirstName).ThenBy(x => x.LastName)
            .Select(x => new { x.Id, x.FirstName, x.LastName })
            .ToListAsync(cancellationToken);
        var names = students.ToDictionary(x => x.Id, x => StudentNames.Short(x.FirstName, x.LastName));

        var grouped = groups
            .SelectMany(x => x.Members.Where(member => member.Status == StudyGroupMemberStatus.Active))
            .Select(x => x.UserId)
            .ToHashSet();

        return Ok(new StudyGroupHomeworkOverviewResponse(
            homeworkId,
            groups.Select(group => new StudyGroupOverviewGroupResponse(
                group.Id,
                group.Name,
                group.Members
                    .Where(x => x.Status == StudyGroupMemberStatus.Active && names.ContainsKey(x.UserId))
                    .Select(x => names[x.UserId])
                    .ToArray(),
                group.Members.Any(x => x.UserId == user.Id && x.Status == StudyGroupMemberStatus.Active))).ToArray(),
            students.Where(x => !grouped.Contains(x.Id)).Select(x => names[x.Id]).ToArray()));
    }

    /// <summary>Mes tâches à faire et mes réunions confirmées, tous groupes confondus.</summary>
    [HttpGet("agenda")]
    public async Task<ActionResult<StudyGroupAgendaResponse>> Agenda(CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Ok(new StudyGroupAgendaResponse([], []));

        var groups = await Db.StudyGroups.AsNoTracking()
            .Include(x => x.Homework)
            .Where(x => x.SchoolClassId == user.SchoolClassId
                && x.Members.Any(member => member.UserId == user.Id && member.Status == StudyGroupMemberStatus.Active))
            .ToListAsync(cancellationToken);
        var now = Clock.UtcNow;
        var activeGroups = groups.Where(x => !x.IsArchivedAt(now)).ToDictionary(x => x.Id);
        var groupIds = activeGroups.Keys.ToArray();

        var tasks = await Db.StudyGroupTasks.AsNoTracking()
            .Where(x => groupIds.Contains(x.StudyGroupId)
                && x.Status != StudyGroupTaskStatus.Done
                && x.Assignees.Any(assignee => assignee.UserId == user.Id))
            .OrderBy(x => x.DueOn)
            .ToListAsync(cancellationToken);
        var meetings = await Db.StudyGroupMeetings.AsNoTracking()
            .Where(x => groupIds.Contains(x.StudyGroupId)
                && x.Status == StudyGroupMeetingStatus.Confirmed
                && x.EndsAt > now.AddDays(-1))
            .OrderBy(x => x.StartsAt)
            .ToListAsync(cancellationToken);

        return Ok(new StudyGroupAgendaResponse(
            tasks.Select(x => new StudyGroupAgendaTaskResponse(
                x.Id,
                x.StudyGroupId,
                activeGroups[x.StudyGroupId].Name,
                Protector.Unprotect(x.EncryptedTitle, TaskPurpose),
                StudyGroupMapping.TaskStatus(x.Status),
                x.DueOn)).ToArray(),
            meetings.Select(x => new StudyGroupAgendaMeetingResponse(
                x.Id,
                x.StudyGroupId,
                activeGroups[x.StudyGroupId].Name,
                x.StartsAt,
                x.EndsAt,
                StudyGroupMapping.MeetingMode(x.Mode),
                UnprotectOptional(x.EncryptedPlace, TextPurpose))).ToArray()));
    }

    /// <summary>Tout est lu jusqu'à maintenant (compteur de non-lus et « vu »).</summary>
    [HttpPut("{id:guid}/read")]
    public async Task<IActionResult> MarkRead(Guid id, CancellationToken cancellationToken)
    {
        var access = await AccessAsync(id, cancellationToken);
        if (access is null) return NotFound();

        var now = Clock.UtcNow;
        access.Member.LastReadAt = now;
        await Db.SaveChangesAsync(cancellationToken);
        await Notifier.ReadAsync(id, access.User.Id, now);
        return NoContent();
    }

    private sealed record Links(Guid? SubjectId, Guid? HomeworkId, DateTimeOffset? DueAt, ObjectResult? Problem);

    private async Task<Links> ResolveLinksAsync(Guid classId, StudyGroupRequest request, CancellationToken cancellationToken)
    {
        var subjectId = request.SubjectId;
        DateTimeOffset? dueAt = request.DueAt?.ToUniversalTime();

        if (request.HomeworkId is { } homeworkId)
        {
            var homework = await Db.HomeworkItems.AsNoTracking()
                .Include(x => x.Course)
                .SingleOrDefaultAsync(x => x.Id == homeworkId && x.SchoolClassId == classId, cancellationToken);
            if (homework is null) return new Links(null, null, null, BadRequestProblem("Ce devoir n'existe pas dans ta classe."));

            subjectId ??= homework.Course?.SubjectId;
            dueAt = homework.Deadline;
        }

        if (subjectId is { } id)
        {
            var subjectExists = await Db.Subjects.AnyAsync(x => x.Id == id && x.SchoolClassId == classId, cancellationToken);
            if (!subjectExists) return new Links(null, null, null, BadRequestProblem("Ce cours n'existe pas dans ta classe."));
        }

        return new Links(subjectId, request.HomeworkId, dueAt, null);
    }

    private Task<bool> IsInGroupForHomeworkAsync(Guid userId, Guid homeworkId, Guid? exceptGroupId, CancellationToken cancellationToken) =>
        Db.StudyGroupMembers.AnyAsync(x => x.UserId == userId
            && x.Status == StudyGroupMemberStatus.Active
            && x.Group.HomeworkId == homeworkId
            && x.StudyGroupId != exceptGroupId, cancellationToken);

    private sealed record Invitees(IReadOnlyList<Guid> UserIds, ObjectResult? Problem);

    private async Task<Invitees> ValidInviteesAsync(
        StudyGroup group,
        IReadOnlyCollection<Guid> requested,
        Guid inviterId,
        CancellationToken cancellationToken)
    {
        var existing = group.Members.Select(x => x.UserId).ToHashSet();
        var ids = requested.Distinct().Where(x => x != inviterId && !existing.Contains(x)).ToList();
        if (ids.Count == 0) return new Invitees([], null);

        if (existing.Count + ids.Count > StudyGroup.MaxMembers)
        {
            return new Invitees([], BadRequestProblem($"Un groupe compte au plus {StudyGroup.MaxMembers} personnes, invitations comprises."));
        }

        var classmates = await Db.Users.AsNoTracking()
            .CountAsync(x => ids.Contains(x.Id) && x.SchoolClassId == group.SchoolClassId && x.IsActive, cancellationToken);
        if (classmates != ids.Count) return new Invitees([], BadRequestProblem("Tu ne peux inviter que des élèves de ta classe."));

        if (group.HomeworkId is { } homeworkId)
        {
            var taken = await Db.StudyGroupMembers.AsNoTracking()
                .Where(x => ids.Contains(x.UserId)
                    && x.Status == StudyGroupMemberStatus.Active
                    && x.Group.HomeworkId == homeworkId
                    && x.StudyGroupId != group.Id)
                .Select(x => x.UserId)
                .ToListAsync(cancellationToken);
            if (taken.Count > 0)
            {
                var names = await NamesAsync(taken, cancellationToken);
                return new Invitees([], ConflictProblem(
                    "Déjà dans un groupe pour ce devoir.",
                    $"{string.Join(", ", names.Values)} a déjà un groupe pour ce devoir."));
            }
        }

        return new Invitees(ids, null);
    }

    private StudyGroupMember NewInvitation(Guid userId, Guid invitedById, Guid? groupId = null) => new()
    {
        StudyGroupId = groupId ?? Guid.Empty,
        UserId = userId,
        Role = StudyGroupRole.Member,
        Status = StudyGroupMemberStatus.Invited,
        InvitedById = invitedById,
        InvitedAt = Clock.UtcNow
    };

    private Task NotifyInvitationAsync(StudyGroup group, IReadOnlyList<Guid> inviteeIds, ApplicationUser inviter, CancellationToken cancellationToken) =>
        inviteeIds.Count == 0
            ? Task.CompletedTask
            : Notifier.PushAsync(
                group.Id,
                inviteeIds,
                "Invitation dans un groupe",
                $"{StudentNames.Short(inviter.FirstName, inviter.LastName)} t'invite dans « {group.Name} ».",
                cancellationToken);

    private async Task RemoveMemberAsync(StudyGroup group, StudyGroupMember member, CancellationToken cancellationToken)
    {
        // Ses tâches restent au groupe, sans lui : quelqu'un d'autre les reprendra.
        await Db.StudyGroupTaskAssignees
            .Where(x => x.UserId == member.UserId && x.Task.StudyGroupId == group.Id)
            .ExecuteDeleteAsync(cancellationToken);
        await Db.StudyGroupMeetingVotes
            .Where(x => x.UserId == member.UserId && x.Meeting.StudyGroupId == group.Id)
            .ExecuteDeleteAsync(cancellationToken);

        Db.StudyGroupMembers.Remove(member);
        await Db.SaveChangesAsync(cancellationToken);
        await Notifier.DisconnectAsync(group.Id, member.UserId);
        await Notifier.ChangedAsync(group.Id, StudyGroupNotifier.Areas.Members);
    }

    private async Task<StudyGroupDetailResponse> DetailAsync(Guid groupId, Guid userId, CancellationToken cancellationToken)
    {
        var group = await Db.StudyGroups.AsNoTracking()
            .Include(x => x.Members)
            .Include(x => x.Homework)
            .Include(x => x.Subject)
            .AsSplitQuery()
            .SingleAsync(x => x.Id == groupId, cancellationToken);
        var summary = (await SummariesAsync([group], userId, cancellationToken)).Single();

        var taskCounts = await Db.StudyGroupTaskAssignees.AsNoTracking()
            .Where(x => x.Task.StudyGroupId == groupId)
            .Select(x => new { x.UserId, Done = x.Task.Status == StudyGroupTaskStatus.Done })
            .ToListAsync(cancellationToken);
        var names = await NamesAsync(group.Members.Select(x => x.UserId), cancellationToken);
        var me = group.Members.Single(x => x.UserId == userId);
        var isActive = me.Status == StudyGroupMemberStatus.Active;

        var members = group.Members
            .Where(x => isActive || x.Status == StudyGroupMemberStatus.Active)
            .OrderByDescending(x => x.Role)
            .ThenBy(x => x.Status == StudyGroupMemberStatus.Invited)
            .ThenBy(x => x.JoinedAt ?? x.InvitedAt)
            .Select(x => new StudyGroupMemberResponse(
                x.UserId,
                names.GetValueOrDefault(x.UserId, "Ancien élève"),
                StudyGroupMapping.Role(x.Role),
                StudyGroupMapping.MemberStatus(x.Status),
                x.RoleLabel,
                x.UserId == userId,
                x.LastReadAt,
                taskCounts.Count(task => task.UserId == x.UserId && !task.Done),
                taskCounts.Count(task => task.UserId == x.UserId && task.Done)))
            .ToArray();

        return new StudyGroupDetailResponse(
            summary,
            isActive ? UnprotectOptional(group.EncryptedDescription, TextPurpose) : null,
            isActive && me.Role == StudyGroupRole.Organizer,
            members);
    }

    private async Task<List<StudyGroupSummaryResponse>> SummariesAsync(
        IReadOnlyCollection<StudyGroup> groups,
        Guid userId,
        CancellationToken cancellationToken)
    {
        var groupIds = groups.Select(x => x.Id).ToArray();
        var tasks = await Db.StudyGroupTasks.AsNoTracking()
            .Where(x => groupIds.Contains(x.StudyGroupId))
            .Select(x => new
            {
                x.StudyGroupId,
                Done = x.Status == StudyGroupTaskStatus.Done,
                Mine = x.Assignees.Any(assignee => assignee.UserId == userId)
            })
            .ToListAsync(cancellationToken);
        var lastMessages = await Db.StudyGroupMessages.AsNoTracking()
            .Where(x => groupIds.Contains(x.StudyGroupId))
            .GroupBy(x => x.StudyGroupId)
            .Select(x => new { GroupId = x.Key, Last = x.Max(message => message.CreatedAt) })
            .ToDictionaryAsync(x => x.GroupId, x => x.Last, cancellationToken);
        var inviterIds = groups
            .SelectMany(x => x.Members)
            .Where(x => x.UserId == userId && x.InvitedById != null)
            .Select(x => x.InvitedById!.Value);
        var inviters = await NamesAsync(inviterIds, cancellationToken);
        var now = Clock.UtcNow;

        var summaries = new List<StudyGroupSummaryResponse>();
        foreach (var group in groups)
        {
            var me = group.Members.Single(x => x.UserId == userId);
            var isActive = me.Status == StudyGroupMemberStatus.Active;
            var unread = 0;
            if (isActive)
            {
                var since = me.LastReadAt ?? me.JoinedAt ?? DateTimeOffset.MinValue;
                unread = await Db.StudyGroupMessages.CountAsync(x => x.StudyGroupId == group.Id
                    && x.CreatedAt > since
                    && x.AuthorId != userId
                    && x.DeletedAt == null, cancellationToken);
            }

            var groupTasks = tasks.Where(x => x.StudyGroupId == group.Id).ToList();
            summaries.Add(new StudyGroupSummaryResponse(
                group.Id,
                group.Name,
                group.SubjectId,
                group.Subject?.Name,
                group.Homework is { DeletedAt: null } ? group.HomeworkId : null,
                group.Homework is { DeletedAt: null } homework ? homework.Title : null,
                group.EffectiveDueAt,
                group.IsArchivedAt(now),
                StudyGroupMapping.MemberStatus(me.Status),
                StudyGroupMapping.Role(me.Role),
                me.InvitedById is { } inviterId ? inviters.GetValueOrDefault(inviterId) : null,
                group.Members.Count(x => x.Status == StudyGroupMemberStatus.Active),
                isActive ? groupTasks.Count : 0,
                isActive ? groupTasks.Count(x => x.Done) : 0,
                isActive ? groupTasks.Count(x => x.Mine && !x.Done) : 0,
                unread,
                lastMessages.TryGetValue(group.Id, out var last) ? last : group.CreatedAt));
        }

        return summaries;
    }
}

public static class StudyGroupMapping
{
    public static string Role(StudyGroupRole role) => role == StudyGroupRole.Organizer ? "organizer" : "member";

    public static string MemberStatus(StudyGroupMemberStatus status) =>
        status == StudyGroupMemberStatus.Active ? "active" : "invited";

    public static string TaskStatus(StudyGroupTaskStatus status) => status switch
    {
        StudyGroupTaskStatus.Doing => "doing",
        StudyGroupTaskStatus.Done => "done",
        _ => "todo"
    };

    public static StudyGroupTaskStatus? ParseTaskStatus(string? value) => value?.Trim().ToLowerInvariant() switch
    {
        null or "" or "todo" => StudyGroupTaskStatus.Todo,
        "doing" => StudyGroupTaskStatus.Doing,
        "done" => StudyGroupTaskStatus.Done,
        _ => null
    };

    public static string MeetingMode(StudyGroupMeetingMode mode) => mode == StudyGroupMeetingMode.OnSite ? "onsite" : "remote";

    public static StudyGroupMeetingMode? ParseMeetingMode(string? value) => value?.Trim().ToLowerInvariant() switch
    {
        "onsite" => StudyGroupMeetingMode.OnSite,
        "remote" => StudyGroupMeetingMode.Remote,
        _ => null
    };

    public static string MeetingStatus(StudyGroupMeetingStatus status) => status switch
    {
        StudyGroupMeetingStatus.Confirmed => "confirmed",
        StudyGroupMeetingStatus.Cancelled => "cancelled",
        _ => "proposed"
    };
}
