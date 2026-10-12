using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StudyFlow.Api.Contracts;
using StudyFlow.Api.Realtime;
using StudyFlow.Application.Exams;
using StudyFlow.Application.Security;
using StudyFlow.Application.Time;
using StudyFlow.Domain.Groups;
using StudyFlow.Infrastructure.Identity;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Api.Controllers;

/// <summary>
/// Le travail d'un groupe : les tâches affectées aux membres (qui arrivent dans leur agenda)
/// et les ressources partagées (liens et petits fichiers, mêmes règles que les fiches de
/// révision). Tout membre peut créer, modifier ou cocher une tâche.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/groups")]
public sealed class StudyGroupWorkController(
    UserManager<ApplicationUser> userManager,
    StudyFlowDbContext dbContext,
    ISensitiveDataProtector protector,
    ISchoolClock clock,
    StudyGroupNotifier notifier)
    : StudyGroupControllerBase(userManager, dbContext, protector, clock, notifier)
{
    private const int MaxTasks = 150;
    private const int MaxResources = 60;
    private const long MaxGroupFileBytes = 100L * 1024 * 1024;

    [HttpGet("{id:guid}/tasks")]
    public async Task<ActionResult<IReadOnlyCollection<StudyGroupTaskResponse>>> ListTasks(Guid id, CancellationToken cancellationToken)
    {
        var access = await AccessAsync(id, cancellationToken);
        if (access is null) return NotFound();

        var tasks = await Db.StudyGroupTasks.AsNoTracking()
            .Include(x => x.Assignees)
            .Where(x => x.StudyGroupId == id)
            .ToListAsync(cancellationToken);
        var names = await NamesAsync(tasks.SelectMany(x => x.Assignees).Select(x => x.UserId), cancellationToken);

        return Ok(tasks
            .OrderBy(x => x.Status == StudyGroupTaskStatus.Done)
            .ThenBy(x => x.DueOn ?? DateOnly.MaxValue)
            .ThenBy(x => x.CreatedAt)
            .Select(x => ToTaskResponse(x, names, access.User.Id))
            .ToArray());
    }

    [HttpPost("{id:guid}/tasks")]
    public async Task<ActionResult<StudyGroupTaskResponse>> CreateTask(Guid id, StudyGroupTaskRequest request, CancellationToken cancellationToken)
    {
        var access = await AccessAsync(id, cancellationToken);
        if (access is null) return NotFound();
        if (access.Group.IsArchivedAt(Clock.UtcNow)) return ArchivedProblem();

        var title = Clean(request.Title);
        if (title is null) return BadRequestProblem("Écris la tâche à faire.");
        var status = StudyGroupMapping.ParseTaskStatus(request.Status);
        if (status is null) return BadRequestProblem("Statut de tâche inconnu.");

        var count = await Db.StudyGroupTasks.CountAsync(x => x.StudyGroupId == id, cancellationToken);
        if (count >= MaxTasks) return BadRequestProblem($"Ce groupe a déjà {MaxTasks} tâches. Supprime celles qui ne servent plus.");

        var assignees = ValidAssignees(access.Group, request.AssigneeIds);
        if (assignees is null) return BadRequestProblem("On ne peut affecter une tâche qu'aux membres du groupe.");

        var task = new StudyGroupTask
        {
            StudyGroupId = id,
            EncryptedTitle = Protector.Protect(title, TaskPurpose),
            EncryptedNotes = ProtectOptional(request.Notes, TaskPurpose),
            Status = status.Value,
            DueOn = request.DueOn,
            CreatedById = access.User.Id,
            CompletedAt = status == StudyGroupTaskStatus.Done ? Clock.UtcNow : null,
            Assignees = assignees.Select(x => new StudyGroupTaskAssignee { UserId = x }).ToList()
        };
        Db.StudyGroupTasks.Add(task);
        await Db.SaveChangesAsync(cancellationToken);

        await Notifier.ChangedAsync(id, StudyGroupNotifier.Areas.Tasks);
        await NotifyAssigneesAsync(access, assignees, title, cancellationToken);

        var names = await NamesAsync(assignees, cancellationToken);
        return Ok(ToTaskResponse(task, names, access.User.Id));
    }

    [HttpPut("tasks/{taskId:guid}")]
    public async Task<ActionResult<StudyGroupTaskResponse>> UpdateTask(Guid taskId, StudyGroupTaskRequest request, CancellationToken cancellationToken)
    {
        var (access, task) = await TaskAccessAsync(taskId, cancellationToken);
        if (access is null || task is null) return NotFound();

        var title = Clean(request.Title);
        if (title is null) return BadRequestProblem("Écris la tâche à faire.");
        var status = request.Status is null ? task.Status : StudyGroupMapping.ParseTaskStatus(request.Status);
        if (status is null) return BadRequestProblem("Statut de tâche inconnu.");

        var assignees = ValidAssignees(access.Group, request.AssigneeIds);
        if (assignees is null) return BadRequestProblem("On ne peut affecter une tâche qu'aux membres du groupe.");

        var previous = task.Assignees.Select(x => x.UserId).ToHashSet();
        task.EncryptedTitle = Protector.Protect(title, TaskPurpose);
        task.EncryptedNotes = ProtectOptional(request.Notes, TaskPurpose);
        task.DueOn = request.DueOn;
        ApplyStatus(task, status.Value);
        task.UpdatedAt = Clock.UtcNow;

        Db.StudyGroupTaskAssignees.RemoveRange(task.Assignees.Where(x => !assignees.Contains(x.UserId)));
        foreach (var userId in assignees.Where(x => !previous.Contains(x)))
        {
            task.Assignees.Add(new StudyGroupTaskAssignee { StudyGroupTaskId = task.Id, UserId = userId });
        }

        await Db.SaveChangesAsync(cancellationToken);
        await Notifier.ChangedAsync(task.StudyGroupId, StudyGroupNotifier.Areas.Tasks);
        await NotifyAssigneesAsync(access, assignees.Where(x => !previous.Contains(x)).ToList(), title, cancellationToken);

        var names = await NamesAsync(assignees, cancellationToken);
        return Ok(ToTaskResponse(task, names, access.User.Id));
    }

    /// <summary>À faire → en cours → fait, en un geste.</summary>
    [HttpPut("tasks/{taskId:guid}/status")]
    public async Task<ActionResult<StudyGroupTaskResponse>> SetTaskStatus(Guid taskId, StudyGroupTaskStatusRequest request, CancellationToken cancellationToken)
    {
        var (access, task) = await TaskAccessAsync(taskId, cancellationToken);
        if (access is null || task is null) return NotFound();

        var status = StudyGroupMapping.ParseTaskStatus(request.Status);
        if (status is null) return BadRequestProblem("Statut de tâche inconnu.");

        ApplyStatus(task, status.Value);
        task.UpdatedAt = Clock.UtcNow;
        await Db.SaveChangesAsync(cancellationToken);
        await Notifier.ChangedAsync(task.StudyGroupId, StudyGroupNotifier.Areas.Tasks);

        var names = await NamesAsync(task.Assignees.Select(x => x.UserId), cancellationToken);
        return Ok(ToTaskResponse(task, names, access.User.Id));
    }

    [HttpDelete("tasks/{taskId:guid}")]
    public async Task<IActionResult> DeleteTask(Guid taskId, CancellationToken cancellationToken)
    {
        var (access, task) = await TaskAccessAsync(taskId, cancellationToken);
        if (access is null || task is null) return NotFound();

        Db.StudyGroupTasks.Remove(task);
        await Db.SaveChangesAsync(cancellationToken);
        await Notifier.ChangedAsync(task.StudyGroupId, StudyGroupNotifier.Areas.Tasks);
        return NoContent();
    }

    [HttpGet("{id:guid}/resources")]
    public async Task<ActionResult<IReadOnlyCollection<StudyGroupResourceResponse>>> ListResources(Guid id, CancellationToken cancellationToken)
    {
        var access = await AccessAsync(id, cancellationToken);
        if (access is null) return NotFound();

        var resources = await Db.StudyGroupResources.AsNoTracking()
            .Where(x => x.StudyGroupId == id)
            .OrderByDescending(x => x.CreatedAt)
            .ToListAsync(cancellationToken);
        var names = await NamesAsync(resources.Where(x => x.AuthorId != null).Select(x => x.AuthorId!.Value), cancellationToken);

        return Ok(resources.Select(x => ToResourceResponse(x, names, access)).ToArray());
    }

    [HttpPost("{id:guid}/links")]
    public async Task<ActionResult<StudyGroupResourceResponse>> AddLink(Guid id, StudyGroupLinkRequest request, CancellationToken cancellationToken)
    {
        var access = await AccessAsync(id, cancellationToken);
        if (access is null) return NotFound();
        if (access.Group.IsArchivedAt(Clock.UtcNow)) return ArchivedProblem();
        if (await Db.StudyGroupResources.CountAsync(x => x.StudyGroupId == id, cancellationToken) >= MaxResources)
        {
            return TooManyResourcesProblem();
        }

        var link = RevisionLinkPolicy.Check(request.Url);
        if (!link.IsAccepted) return BadRequestProblem(link.Error!);

        var title = Clean(request.Title) ?? link.Host!;
        var resource = new StudyGroupResource
        {
            StudyGroupId = id,
            AuthorId = access.User.Id,
            Kind = StudyGroupResourceKind.Link,
            EncryptedTitle = Protector.Protect(title, TextPurpose),
            EncryptedUrl = Protector.Protect(link.NormalizedUrl!, TextPurpose)
        };
        Db.StudyGroupResources.Add(resource);
        await Db.SaveChangesAsync(cancellationToken);
        await Notifier.ChangedAsync(id, StudyGroupNotifier.Areas.Resources);

        return Ok(ToResourceResponse(resource, new Dictionary<Guid, string> { [access.User.Id] = Me(access) }, access));
    }

    /// <summary>Fichier contrôlé comme dans les fiches de révision, puis chiffré en base.</summary>
    [HttpPost("{id:guid}/files")]
    [RequestSizeLimit(RevisionFilePolicy.MaxUploadBytes + 64 * 1024)]
    [RequestFormLimits(MultipartBodyLengthLimit = RevisionFilePolicy.MaxUploadBytes + 64 * 1024)]
    public async Task<ActionResult<StudyGroupResourceResponse>> AddFile(
        Guid id,
        IFormFile? file,
        [FromForm] string? title,
        CancellationToken cancellationToken)
    {
        var access = await AccessAsync(id, cancellationToken);
        if (access is null) return NotFound();
        if (access.Group.IsArchivedAt(Clock.UtcNow)) return ArchivedProblem();
        if (await Db.StudyGroupResources.CountAsync(x => x.StudyGroupId == id, cancellationToken) >= MaxResources)
        {
            return TooManyResourcesProblem();
        }

        if (file is null || file.Length == 0) return BadRequestProblem("Choisis un fichier à partager.");
        if (file.Length > RevisionFilePolicy.MaxUploadBytes)
        {
            return BadRequestProblem($"Fichier trop lourd : {RevisionFilePolicy.MaxUploadBytes / (1024 * 1024)} Mo maximum.");
        }

        using var buffer = new MemoryStream((int)file.Length);
        await file.CopyToAsync(buffer, cancellationToken);
        var content = buffer.ToArray();

        var check = RevisionFilePolicy.Inspect(file.FileName, content);
        if (!check.IsAccepted) return BadRequestProblem(check.Error!);

        var classBytes = await Db.StudyGroupResources
            .Where(x => x.Group.SchoolClassId == access.Group.SchoolClassId && x.SizeBytes != null)
            .SumAsync(x => x.SizeBytes!.Value, cancellationToken);
        if (classBytes + content.Length > MaxGroupFileBytes * 3)
        {
            return BadRequestProblem("L'espace des groupes de ta classe est plein. Partage plutôt un lien.");
        }

        var groupBytes = await Db.StudyGroupResources
            .Where(x => x.StudyGroupId == id && x.SizeBytes != null)
            .SumAsync(x => x.SizeBytes!.Value, cancellationToken);
        if (groupBytes + content.Length > MaxGroupFileBytes)
        {
            return BadRequestProblem("L'espace du groupe pour les fichiers est plein. Partage plutôt un lien.");
        }

        var resourceTitle = Clean(title) ?? Path.GetFileNameWithoutExtension(check.FileName!);
        if (resourceTitle.Length > 120) resourceTitle = resourceTitle[..120];

        var resource = new StudyGroupResource
        {
            StudyGroupId = id,
            AuthorId = access.User.Id,
            Kind = StudyGroupResourceKind.File,
            EncryptedTitle = Protector.Protect(resourceTitle, TextPurpose),
            FileName = check.FileName,
            FileType = check.FileType,
            ContentType = check.ContentType,
            SizeBytes = content.Length,
            File = new StudyGroupResourceFile { EncryptedContent = Protector.ProtectBytes(content, FilePurpose) }
        };
        Db.StudyGroupResources.Add(resource);
        await Db.SaveChangesAsync(cancellationToken);
        await Notifier.ChangedAsync(id, StudyGroupNotifier.Areas.Resources);

        return Ok(ToResourceResponse(resource, new Dictionary<Guid, string> { [access.User.Id] = Me(access) }, access));
    }

    [HttpGet("resources/{resourceId:guid}/file")]
    public async Task<IActionResult> DownloadFile(Guid resourceId, CancellationToken cancellationToken)
    {
        var groupId = await Db.StudyGroupResources
            .Where(x => x.Id == resourceId && x.Kind == StudyGroupResourceKind.File)
            .Select(x => (Guid?)x.StudyGroupId)
            .SingleOrDefaultAsync(cancellationToken);
        if (groupId is null || await AccessAsync(groupId.Value, cancellationToken) is null) return NotFound();

        var resource = await Db.StudyGroupResources.AsNoTracking()
            .Include(x => x.File)
            .SingleAsync(x => x.Id == resourceId, cancellationToken);
        if (resource.File is null) return NotFound();

        Response.Headers["X-Content-Type-Options"] = "nosniff";
        Response.Headers["Content-Security-Policy"] = "sandbox allow-scripts; default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:";
        return File(
            Protector.UnprotectBytes(resource.File.EncryptedContent, FilePurpose),
            resource.ContentType ?? "application/octet-stream",
            resource.FileName ?? "fichier");
    }

    [HttpDelete("resources/{resourceId:guid}")]
    public async Task<IActionResult> DeleteResource(Guid resourceId, CancellationToken cancellationToken)
    {
        var resource = await Db.StudyGroupResources.SingleOrDefaultAsync(x => x.Id == resourceId, cancellationToken);
        if (resource is null) return NotFound();
        var access = await AccessAsync(resource.StudyGroupId, cancellationToken);
        if (access is null) return NotFound();
        if (resource.AuthorId != access.User.Id && !access.IsOrganizer) return Forbid();

        Db.StudyGroupResources.Remove(resource);
        await Db.SaveChangesAsync(cancellationToken);
        await Notifier.ChangedAsync(resource.StudyGroupId, StudyGroupNotifier.Areas.Resources);
        return NoContent();
    }

    private async Task<(GroupAccess? Access, StudyGroupTask? Task)> TaskAccessAsync(Guid taskId, CancellationToken cancellationToken)
    {
        var task = await Db.StudyGroupTasks
            .Include(x => x.Assignees)
            .SingleOrDefaultAsync(x => x.Id == taskId, cancellationToken);
        if (task is null) return (null, null);

        var access = await AccessAsync(task.StudyGroupId, cancellationToken);
        return access is null ? (null, null) : (access, task);
    }

    private void ApplyStatus(StudyGroupTask task, StudyGroupTaskStatus status)
    {
        if (task.Status == status) return;
        task.Status = status;
        task.CompletedAt = status == StudyGroupTaskStatus.Done ? Clock.UtcNow : null;
    }

    /// <summary>Les personnes choisies, si toutes sont membres actifs du groupe ; nul sinon.</summary>
    private static List<Guid>? ValidAssignees(StudyGroup group, IReadOnlyCollection<Guid>? requested)
    {
        var ids = (requested ?? []).Distinct().ToList();
        var members = group.Members.Where(x => x.Status == StudyGroupMemberStatus.Active).Select(x => x.UserId).ToHashSet();
        return ids.All(members.Contains) ? ids : null;
    }

    private Task NotifyAssigneesAsync(GroupAccess access, IReadOnlyCollection<Guid> assignees, string title, CancellationToken cancellationToken) =>
        Notifier.PushAsync(
            access.Group.Id,
            assignees.Where(x => x != access.User.Id),
            $"Nouvelle tâche · {access.Group.Name}",
            $"{Me(access)} t'a confié : {title}",
            cancellationToken);

    private static string Me(GroupAccess access) => StudentNames.Short(access.User.FirstName, access.User.LastName);

    private ObjectResult TooManyResourcesProblem() =>
        BadRequestProblem($"Ce groupe a déjà {MaxResources} ressources. Retire celles qui ne servent plus.");

    private StudyGroupTaskResponse ToTaskResponse(StudyGroupTask task, IReadOnlyDictionary<Guid, string> names, Guid userId)
    {
        var assigneeIds = task.Assignees.Select(x => x.UserId).ToArray();
        return new StudyGroupTaskResponse(
            task.Id,
            task.StudyGroupId,
            Protector.Unprotect(task.EncryptedTitle, TaskPurpose),
            UnprotectOptional(task.EncryptedNotes, TaskPurpose),
            StudyGroupMapping.TaskStatus(task.Status),
            task.DueOn,
            assigneeIds,
            assigneeIds.Select(x => names.GetValueOrDefault(x, "Ancien élève")).ToArray(),
            assigneeIds.Contains(userId),
            task.CompletedAt,
            task.CreatedAt,
            task.UpdatedAt);
    }

    private StudyGroupResourceResponse ToResourceResponse(
        StudyGroupResource resource,
        IReadOnlyDictionary<Guid, string> names,
        GroupAccess access) =>
        new(
            resource.Id,
            resource.Kind == StudyGroupResourceKind.Link ? "link" : "file",
            Protector.Unprotect(resource.EncryptedTitle, TextPurpose),
            UnprotectOptional(resource.EncryptedUrl, TextPurpose),
            resource.FileName,
            resource.FileType,
            resource.SizeBytes,
            resource.AuthorId is { } authorId ? names.GetValueOrDefault(authorId, "Ancien élève") : "Ancien élève",
            resource.AuthorId == access.User.Id,
            resource.AuthorId == access.User.Id || access.IsOrganizer,
            resource.CreatedAt);
}
