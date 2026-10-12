using System.ComponentModel.DataAnnotations;

namespace StudyFlow.Api.Contracts;

public sealed record StudyGroupRequest(
    [StringLength(60, ErrorMessage = "Nom : 60 caractères maximum.")] string Name,
    [StringLength(2000, ErrorMessage = "Description : 2000 caractères maximum.")] string? Description = null,
    Guid? SubjectId = null,
    Guid? HomeworkId = null,
    DateTimeOffset? DueAt = null,
    IReadOnlyCollection<Guid>? InviteeIds = null);

public sealed record StudyGroupInviteRequest(IReadOnlyCollection<Guid> UserIds);

public sealed record StudyGroupRoleLabelRequest(
    [StringLength(40, ErrorMessage = "Rôle : 40 caractères maximum.")] string? RoleLabel);

/// <param name="Status">invited (invitation reçue) ou active.</param>
/// <param name="MyRole">organizer ou member.</param>
public sealed record StudyGroupSummaryResponse(
    Guid Id,
    string Name,
    Guid? SubjectId,
    string? SubjectName,
    Guid? HomeworkId,
    string? HomeworkTitle,
    DateTimeOffset? DueAt,
    bool IsArchived,
    string Status,
    string MyRole,
    string? InvitedByName,
    int MemberCount,
    int TaskCount,
    int DoneTaskCount,
    int MyOpenTaskCount,
    int UnreadCount,
    DateTimeOffset? LastActivityAt);

public sealed record StudyGroupMemberResponse(
    Guid UserId,
    string Name,
    string Role,
    string Status,
    string? RoleLabel,
    bool IsMe,
    DateTimeOffset? LastReadAt,
    int OpenTaskCount,
    int DoneTaskCount);

public sealed record StudyGroupDetailResponse(
    StudyGroupSummaryResponse Summary,
    string? Description,
    bool CanManage,
    IReadOnlyCollection<StudyGroupMemberResponse> Members);

public sealed record StudyGroupClassmateResponse(Guid UserId, string Name, string? GroupName, bool IsInvitedHere);

public sealed record StudyGroupOverviewGroupResponse(Guid Id, string Name, IReadOnlyCollection<string> MemberNames, bool IsMine);

/// <summary>Qui a déjà formé un groupe pour ce devoir, sans rien montrer de son contenu.</summary>
public sealed record StudyGroupHomeworkOverviewResponse(
    Guid HomeworkId,
    IReadOnlyCollection<StudyGroupOverviewGroupResponse> Groups,
    IReadOnlyCollection<string> StudentsWithoutGroup);

public sealed record StudyGroupTaskRequest(
    [StringLength(160, ErrorMessage = "Tâche : 160 caractères maximum.")] string Title,
    [StringLength(2000, ErrorMessage = "Notes : 2000 caractères maximum.")] string? Notes = null,
    DateOnly? DueOn = null,
    IReadOnlyCollection<Guid>? AssigneeIds = null,
    string? Status = null);

public sealed record StudyGroupTaskStatusRequest(string Status);

public sealed record StudyGroupTaskResponse(
    Guid Id,
    Guid GroupId,
    string Title,
    string? Notes,
    string Status,
    DateOnly? DueOn,
    IReadOnlyCollection<Guid> AssigneeIds,
    IReadOnlyCollection<string> AssigneeNames,
    bool IsMine,
    DateTimeOffset? CompletedAt,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

public sealed record StudyGroupMessageRequest(
    [StringLength(2000, ErrorMessage = "Message : 2000 caractères maximum.")] string Text);

/// <param name="AuthorId">Nul pour un message du système (arrivée, départ, réunion confirmée…).</param>
public sealed record StudyGroupMessageResponse(
    Guid Id,
    Guid GroupId,
    Guid? AuthorId,
    string? AuthorName,
    string Text,
    bool IsMine,
    bool IsDeleted,
    DateTimeOffset CreatedAt);

public sealed record StudyGroupLinkRequest(
    [StringLength(2000)] string Url,
    [StringLength(120)] string? Title = null);

public sealed record StudyGroupResourceResponse(
    Guid Id,
    string Kind,
    string Title,
    string? Url,
    string? FileName,
    string? FileType,
    long? SizeBytes,
    string AuthorName,
    bool IsMine,
    bool CanDelete,
    DateTimeOffset CreatedAt);

public sealed record UserAvailabilityRequest(
    TimeOnly CompanyEndsAt,
    TimeOnly AvailableUntil,
    bool WeekendAvailable,
    bool UsePersonalAgenda = true);

public sealed record UserAvailabilityResponse(
    TimeOnly CompanyEndsAt,
    TimeOnly AvailableUntil,
    bool WeekendAvailable,
    bool UsePersonalAgenda,
    bool IsDefault);

/// <param name="Mode">onsite (à l'école) ou remote (à distance).</param>
public sealed record StudyGroupSlotResponse(
    DateOnly Day,
    TimeOnly StartsAt,
    TimeOnly EndsAt,
    string Mode,
    IReadOnlyCollection<string> MissingNames);

public sealed record StudyGroupSlotsResponse(
    int DurationMinutes,
    IReadOnlyCollection<StudyGroupSlotResponse> Slots,
    IReadOnlyCollection<string> MembersWithDefaultAvailability);

public sealed record StudyGroupMeetingRequest(
    DateTimeOffset StartsAt,
    DateTimeOffset EndsAt,
    string Mode,
    [StringLength(200, ErrorMessage = "Lieu : 200 caractères maximum.")] string? Place = null);

public sealed record StudyGroupMeetingVoteRequest(bool IsAvailable);

public sealed record StudyGroupMeetingVoteResponse(Guid UserId, string Name, bool? IsAvailable);

public sealed record StudyGroupMeetingResponse(
    Guid Id,
    Guid GroupId,
    DateTimeOffset StartsAt,
    DateTimeOffset EndsAt,
    string Mode,
    string? Place,
    string Status,
    string? ProposedByName,
    bool CanCancel,
    bool? MyAnswer,
    IReadOnlyCollection<StudyGroupMeetingVoteResponse> Votes);

/// <summary>Ce qui concerne l'élève dans tous ses groupes : pour l'accueil, l'agenda et les rappels.</summary>
public sealed record StudyGroupAgendaResponse(
    IReadOnlyCollection<StudyGroupAgendaTaskResponse> Tasks,
    IReadOnlyCollection<StudyGroupAgendaMeetingResponse> Meetings);

public sealed record StudyGroupAgendaTaskResponse(
    Guid Id,
    Guid GroupId,
    string GroupName,
    string Title,
    string Status,
    DateOnly? DueOn);

public sealed record StudyGroupAgendaMeetingResponse(
    Guid Id,
    Guid GroupId,
    string GroupName,
    DateTimeOffset StartsAt,
    DateTimeOffset EndsAt,
    string Mode,
    string? Place);
