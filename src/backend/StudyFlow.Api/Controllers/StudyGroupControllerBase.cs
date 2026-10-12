using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StudyFlow.Api.Realtime;
using StudyFlow.Application.Security;
using StudyFlow.Application.Time;
using StudyFlow.Domain.Groups;
using StudyFlow.Infrastructure.Identity;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Api.Controllers;

/// <summary>
/// Socle des contrôleurs de groupes : un élève n'accède à un groupe que s'il en est membre
/// et qu'il est toujours dans la classe du groupe. Tout ce qui est écrit dans un groupe est
/// chiffré en base.
/// </summary>
public abstract class StudyGroupControllerBase(
    UserManager<ApplicationUser> userManager,
    StudyFlowDbContext dbContext,
    ISensitiveDataProtector protector,
    ISchoolClock clock,
    StudyGroupNotifier notifier) : StudyFlowControllerBase(userManager)
{
    protected const string TextPurpose = "study-group-text";
    protected const string TaskPurpose = "study-group-task";
    protected const string FilePurpose = "study-group-file";

    protected StudyFlowDbContext Db { get; } = dbContext;
    protected ISensitiveDataProtector Protector { get; } = protector;
    protected ISchoolClock Clock { get; } = clock;
    protected StudyGroupNotifier Notifier { get; } = notifier;

    protected sealed record GroupAccess(ApplicationUser User, StudyGroup Group, StudyGroupMember Member)
    {
        public bool IsOrganizer => Member.Role == StudyGroupRole.Organizer;
    }

    /// <summary>
    /// Accès d'un membre actif (ou invité si <paramref name="allowInvited"/>). Nul si l'élève
    /// n'en fait pas partie : on répond alors 404, sans révéler que le groupe existe.
    /// </summary>
    protected async Task<GroupAccess?> AccessAsync(Guid groupId, CancellationToken cancellationToken, bool allowInvited = false)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return null;

        var group = await Db.StudyGroups
            .Include(x => x.Members)
            .Include(x => x.Homework)
            .Include(x => x.Subject)
            .AsSplitQuery()
            .SingleOrDefaultAsync(x => x.Id == groupId && x.SchoolClassId == user.SchoolClassId, cancellationToken);
        var member = group?.Members.SingleOrDefault(x => x.UserId == user.Id);
        if (group is null || member is null) return null;
        if (member.Status != StudyGroupMemberStatus.Active && !allowInvited) return null;

        return new GroupAccess(user, group, member);
    }

    protected IEnumerable<Guid> ActiveMemberIds(StudyGroup group) =>
        group.Members.Where(x => x.Status == StudyGroupMemberStatus.Active).Select(x => x.UserId);

    protected async Task<Dictionary<Guid, string>> NamesAsync(IEnumerable<Guid> userIds, CancellationToken cancellationToken)
    {
        var ids = userIds.Distinct().ToArray();
        if (ids.Length == 0) return [];
        var users = await Db.Users.AsNoTracking()
            .Where(x => ids.Contains(x.Id))
            .Select(x => new { x.Id, x.FirstName, x.LastName })
            .ToListAsync(cancellationToken);
        return users.ToDictionary(x => x.Id, x => StudentNames.Short(x.FirstName, x.LastName));
    }

    protected string? ProtectOptional(string? value, string purpose)
    {
        var cleaned = Clean(value);
        return cleaned is null ? null : Protector.Protect(cleaned, purpose);
    }

    protected string? UnprotectOptional(string? value, string purpose) =>
        string.IsNullOrEmpty(value) ? null : Protector.Unprotect(value, purpose);

    protected static string? Clean(string? value)
    {
        var cleaned = value?.Trim();
        return string.IsNullOrEmpty(cleaned) ? null : cleaned;
    }

    protected ObjectResult ArchivedProblem() =>
        BadRequestProblem("Ce groupe est archivé : le rendu est passé depuis plus d'une semaine.");
}

public static class StudentNames
{
    /// <summary>« Léa M. » : le prénom suffit dans une classe, l'initiale lève les homonymes.</summary>
    public static string Short(string firstName, string lastName)
    {
        var first = firstName.Trim();
        var last = lastName.Trim();
        return last.Length == 0 ? first : $"{first} {char.ToUpperInvariant(last[0])}.";
    }
}
