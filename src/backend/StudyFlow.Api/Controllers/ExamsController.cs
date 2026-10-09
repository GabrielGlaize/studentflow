using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StudyFlow.Api.Contracts;
using StudyFlow.Application.Exams;
using StudyFlow.Application.Time;
using StudyFlow.Domain.Exams;
using StudyFlow.Domain.Users;
using StudyFlow.Infrastructure.Identity;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Api.Controllers;

/// <summary>
/// Partiels : les délégués déclarent la période et les épreuves ; deux semaines avant, une fiche
/// de révision s'ouvre pour chaque matière. Chaque élève peut y ajouter des points à réviser,
/// des liens et de petits fichiers ; l'auteur ou un délégué peut les retirer.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/exams")]
public sealed class ExamsController(
    UserManager<ApplicationUser> userManager,
    StudyFlowDbContext dbContext,
    ISchoolClock clock) : StudyFlowControllerBase(userManager)
{
    private const int MaxSessionDays = 31;
    private const int MaxResourcesPerSubject = 40;
    private const long MaxClassFileBytes = 300L * 1024 * 1024;

    /// <summary>
    /// Partiels visibles : ceux dont la fiche est ouverte pour tous, et pour un délégué ceux
    /// qu'il prépare (pas encore ouverts) ou terminés depuis moins d'un mois.
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<IReadOnlyCollection<ExamSessionResponse>>> List(CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var today = clock.Today;
        var isDelegate = IsDelegate;
        var oldestEnd = isDelegate ? today.AddDays(-30) : today;
        var sessions = await dbContext.ExamSessions
            .AsNoTracking()
            .Include(x => x.Subjects).ThenInclude(x => x.Subject)
            .Where(x => x.SchoolClassId == user.SchoolClassId && x.EndsOn >= oldestEnd)
            .OrderBy(x => x.StartsOn)
            .ToListAsync(cancellationToken);

        var visible = sessions.Where(x => isDelegate || x.IsOpenOn(today)).ToList();
        var responses = new List<ExamSessionResponse>();
        foreach (var session in visible)
        {
            responses.Add(await ToSessionResponseAsync(session, user.Id, cancellationToken));
        }

        return Ok(responses);
    }

    [Authorize(Roles = nameof(UserRole.Delegue))]
    [HttpPost]
    public async Task<ActionResult<ExamSessionResponse>> Create(ExamSessionRequest request, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var problem = await ValidateSessionAsync(user.SchoolClassId.Value, request, cancellationToken);
        if (problem is not null) return problem;

        var session = new ExamSession
        {
            SchoolClassId = user.SchoolClassId.Value,
            Title = request.Title.Trim(),
            StartsOn = request.StartsOn,
            EndsOn = request.EndsOn,
            CreatedById = user.Id
        };
        session.Subjects = request.Subjects
            .Select((subject, index) => NewExamSubject(subject, index))
            .ToList();

        dbContext.ExamSessions.Add(session);
        await dbContext.SaveChangesAsync(cancellationToken);

        var saved = await LoadSessionAsync(session.Id, cancellationToken);
        return CreatedAtAction(nameof(List), await ToSessionResponseAsync(saved!, user.Id, cancellationToken));
    }

    /// <summary>
    /// Met à jour les dates et la liste des épreuves. Une matière retirée emporte sa fiche ;
    /// une matière gardée conserve les points et ressources déjà ajoutés.
    /// </summary>
    [Authorize(Roles = nameof(UserRole.Delegue))]
    [HttpPut("{id:guid}")]
    public async Task<ActionResult<ExamSessionResponse>> Update(
        Guid id,
        ExamSessionRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var session = await dbContext.ExamSessions
            .Include(x => x.Subjects)
            .SingleOrDefaultAsync(x => x.Id == id && x.SchoolClassId == user.SchoolClassId, cancellationToken);
        if (session is null) return NotFound();

        var problem = await ValidateSessionAsync(user.SchoolClassId.Value, request, cancellationToken);
        if (problem is not null) return problem;

        session.Title = request.Title.Trim();
        session.StartsOn = request.StartsOn;
        session.EndsOn = request.EndsOn;
        session.UpdatedAt = DateTimeOffset.UtcNow;

        var requested = request.Subjects.ToList();
        foreach (var removed in session.Subjects.Where(x => requested.All(r => r.SubjectId != x.SubjectId)).ToList())
        {
            dbContext.ExamSubjects.Remove(removed);
        }

        for (var index = 0; index < requested.Count; index++)
        {
            var item = requested[index];
            var existing = session.Subjects.FirstOrDefault(x => x.SubjectId == item.SubjectId);
            if (existing is null)
            {
                var created = NewExamSubject(item, index);
                created.ExamSessionId = session.Id;
                dbContext.ExamSubjects.Add(created);
                continue;
            }

            existing.ExamDay = item.ExamDay;
            existing.StartsAt = item.StartsAt;
            existing.Details = Clean(item.Details);
            existing.Position = index;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        var saved = await LoadSessionAsync(session.Id, cancellationToken);
        return Ok(await ToSessionResponseAsync(saved!, user.Id, cancellationToken));
    }

    [Authorize(Roles = nameof(UserRole.Delegue))]
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var session = await dbContext.ExamSessions
            .SingleOrDefaultAsync(x => x.Id == id && x.SchoolClassId == user.SchoolClassId, cancellationToken);
        if (session is null) return NotFound();

        dbContext.ExamSessions.Remove(session);
        await dbContext.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    [HttpGet("subjects/{id:guid}")]
    public async Task<ActionResult<ExamSubjectSheetResponse>> GetSheet(Guid id, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var examSubject = await FindVisibleSubjectAsync(id, user.SchoolClassId.Value, cancellationToken);
        if (examSubject is null) return NotFound();

        return Ok(await ToSheetResponseAsync(examSubject, user.Id, cancellationToken));
    }

    [HttpPost("subjects/{id:guid}/items")]
    public async Task<ActionResult<RevisionItemResponse>> AddItem(
        Guid id,
        RevisionItemRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var examSubject = await FindVisibleSubjectAsync(id, user.SchoolClassId.Value, cancellationToken);
        if (examSubject is null) return NotFound();
        if (!CanContribute(examSubject.Session)) return ClosedProblem();

        var text = request.Text.Trim();
        if (text.Length == 0) return BadRequestProblem("Écris le point à réviser.");

        var item = new RevisionItem { ExamSubjectId = examSubject.Id, AuthorId = user.Id, Text = text };
        dbContext.RevisionItems.Add(item);
        await dbContext.SaveChangesAsync(cancellationToken);

        return Ok(ToItemResponse(item, AuthorName(user.FirstName, user.LastName), user.Id, checkedByMe: false, checkCount: 0));
    }

    [HttpPut("items/{id:guid}")]
    public async Task<ActionResult<RevisionItemResponse>> UpdateItem(
        Guid id,
        RevisionItemRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var item = await dbContext.RevisionItems
            .Include(x => x.ExamSubject).ThenInclude(x => x.Session)
            .Include(x => x.Checks)
            .SingleOrDefaultAsync(x => x.Id == id && x.ExamSubject.Session.SchoolClassId == user.SchoolClassId, cancellationToken);
        if (item is null || !IsVisible(item.ExamSubject.Session)) return NotFound();
        if (!CanContribute(item.ExamSubject.Session)) return ClosedProblem();
        if (!CanModerate(item.AuthorId, user.Id)) return Forbid();

        var text = request.Text.Trim();
        if (text.Length == 0) return BadRequestProblem("Écris le point à réviser.");

        item.Text = text;
        item.UpdatedAt = DateTimeOffset.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);

        var authorName = await AuthorNameAsync(item.AuthorId, cancellationToken);
        return Ok(ToItemResponse(item, authorName, user.Id, item.Checks.Any(x => x.UserId == user.Id), item.Checks.Count));
    }

    [HttpDelete("items/{id:guid}")]
    public async Task<IActionResult> DeleteItem(Guid id, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var item = await dbContext.RevisionItems
            .Include(x => x.ExamSubject).ThenInclude(x => x.Session)
            .SingleOrDefaultAsync(x => x.Id == id && x.ExamSubject.Session.SchoolClassId == user.SchoolClassId, cancellationToken);
        if (item is null || !IsVisible(item.ExamSubject.Session)) return NotFound();
        if (!CanModerate(item.AuthorId, user.Id)) return Forbid();

        dbContext.RevisionItems.Remove(item);
        await dbContext.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    /// <summary>Case personnelle « révisé » : chacun suit sa propre progression.</summary>
    [HttpPut("items/{id:guid}/check")]
    public async Task<IActionResult> CheckItem(Guid id, RevisionCheckRequest request, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var item = await dbContext.RevisionItems
            .Include(x => x.ExamSubject).ThenInclude(x => x.Session)
            .SingleOrDefaultAsync(x => x.Id == id && x.ExamSubject.Session.SchoolClassId == user.SchoolClassId, cancellationToken);
        if (item is null || !IsVisible(item.ExamSubject.Session)) return NotFound();

        var check = await dbContext.RevisionItemChecks
            .SingleOrDefaultAsync(x => x.RevisionItemId == id && x.UserId == user.Id, cancellationToken);
        if (request.Checked && check is null)
        {
            dbContext.RevisionItemChecks.Add(new RevisionItemCheck { RevisionItemId = id, UserId = user.Id });
        }
        else if (!request.Checked && check is not null)
        {
            dbContext.RevisionItemChecks.Remove(check);
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    [HttpPost("subjects/{id:guid}/links")]
    public async Task<ActionResult<RevisionResourceResponse>> AddLink(
        Guid id,
        RevisionLinkRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var examSubject = await FindVisibleSubjectAsync(id, user.SchoolClassId.Value, cancellationToken);
        if (examSubject is null) return NotFound();
        if (!CanContribute(examSubject.Session)) return ClosedProblem();
        if (examSubject.Resources.Count >= MaxResourcesPerSubject) return TooManyResourcesProblem();

        var link = RevisionLinkPolicy.Check(request.Url);
        if (!link.IsAccepted) return BadRequestProblem(link.Error!);

        var resource = new RevisionResource
        {
            ExamSubjectId = examSubject.Id,
            AuthorId = user.Id,
            Kind = RevisionResourceKind.Link,
            Url = link.NormalizedUrl,
            Title = Clean(request.Title) ?? link.Host!
        };
        dbContext.RevisionResources.Add(resource);
        await dbContext.SaveChangesAsync(cancellationToken);

        return Ok(ToResourceResponse(resource, AuthorName(user.FirstName, user.LastName), user.Id));
    }

    /// <summary>
    /// Ajoute un fichier après contrôle de son contenu (liste blanche, signature, taille).
    /// Il est stocké en base et n'est jamais exécuté par le serveur.
    /// </summary>
    [HttpPost("subjects/{id:guid}/files")]
    [RequestSizeLimit(RevisionFilePolicy.MaxUploadBytes + 64 * 1024)]
    [RequestFormLimits(MultipartBodyLengthLimit = RevisionFilePolicy.MaxUploadBytes + 64 * 1024)]
    public async Task<ActionResult<RevisionResourceResponse>> AddFile(
        Guid id,
        IFormFile? file,
        [FromForm] string? title,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var examSubject = await FindVisibleSubjectAsync(id, user.SchoolClassId.Value, cancellationToken);
        if (examSubject is null) return NotFound();
        if (!CanContribute(examSubject.Session)) return ClosedProblem();
        if (examSubject.Resources.Count >= MaxResourcesPerSubject) return TooManyResourcesProblem();

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

        var classBytes = await dbContext.RevisionResources
            .Where(x => x.ExamSubject.Session.SchoolClassId == user.SchoolClassId && x.SizeBytes != null)
            .SumAsync(x => x.SizeBytes!.Value, cancellationToken);
        if (classBytes + content.Length > MaxClassFileBytes)
        {
            return BadRequestProblem("L'espace de la classe pour les fichiers est plein. Partage plutôt un lien.");
        }

        var resource = new RevisionResource
        {
            ExamSubjectId = examSubject.Id,
            AuthorId = user.Id,
            Kind = RevisionResourceKind.File,
            Title = Clean(title) ?? Path.GetFileNameWithoutExtension(check.FileName!),
            FileName = check.FileName,
            FileType = check.FileType,
            ContentType = check.ContentType,
            SizeBytes = content.Length,
            File = new RevisionResourceFile { Content = content }
        };
        if (resource.Title.Length > 120) resource.Title = resource.Title[..120];

        dbContext.RevisionResources.Add(resource);
        await dbContext.SaveChangesAsync(cancellationToken);

        return Ok(ToResourceResponse(resource, AuthorName(user.FirstName, user.LastName), user.Id));
    }

    /// <summary>
    /// Renvoie le fichier en téléchargement, avec un type fixé par le serveur et une politique
    /// de sécurité qui isole une page HTML si un navigateur venait à l'afficher.
    /// </summary>
    [HttpGet("resources/{id:guid}/file")]
    public async Task<IActionResult> DownloadFile(Guid id, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var resource = await dbContext.RevisionResources
            .AsNoTracking()
            .Include(x => x.ExamSubject).ThenInclude(x => x.Session)
            .Include(x => x.File)
            .SingleOrDefaultAsync(x => x.Id == id
                && x.Kind == RevisionResourceKind.File
                && x.ExamSubject.Session.SchoolClassId == user.SchoolClassId, cancellationToken);
        if (resource?.File is null || !IsVisible(resource.ExamSubject.Session)) return NotFound();

        Response.Headers["X-Content-Type-Options"] = "nosniff";
        Response.Headers["Content-Security-Policy"] = "sandbox allow-scripts; default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:";
        return File(resource.File.Content, resource.ContentType ?? "application/octet-stream", resource.FileName ?? "fichier");
    }

    [HttpDelete("resources/{id:guid}")]
    public async Task<IActionResult> DeleteResource(Guid id, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user?.SchoolClassId is null) return Forbid();

        var resource = await dbContext.RevisionResources
            .Include(x => x.ExamSubject).ThenInclude(x => x.Session)
            .SingleOrDefaultAsync(x => x.Id == id && x.ExamSubject.Session.SchoolClassId == user.SchoolClassId, cancellationToken);
        if (resource is null || !IsVisible(resource.ExamSubject.Session)) return NotFound();
        if (!CanModerate(resource.AuthorId, user.Id)) return Forbid();

        dbContext.RevisionResources.Remove(resource);
        await dbContext.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    private bool IsDelegate => User.IsInRole(nameof(UserRole.Delegue));

    private bool IsVisible(ExamSession session) => IsDelegate || session.IsOpenOn(clock.Today);

    /// <summary>Les délégués peuvent remplir la fiche en avance ; les élèves une fois ouverte.</summary>
    private bool CanContribute(ExamSession session) =>
        session.EndsOn >= clock.Today && (IsDelegate || session.IsOpenOn(clock.Today));

    private bool CanModerate(Guid authorId, Guid userId) => authorId == userId || IsDelegate;

    private ObjectResult ClosedProblem() =>
        BadRequestProblem("La fiche de révision n'est pas ouverte : elle s'ouvre deux semaines avant les partiels.");

    private ObjectResult TooManyResourcesProblem() =>
        BadRequestProblem($"Cette matière a déjà {MaxResourcesPerSubject} ressources. Retire celles qui ne servent plus.");

    private async Task<ObjectResult?> ValidateSessionAsync(
        Guid schoolClassId,
        ExamSessionRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Title)) return BadRequestProblem("Donne un nom aux partiels (ex. Partiels du semestre 1).");
        if (request.EndsOn < request.StartsOn) return BadRequestProblem("La dernière épreuve doit être après la première.");
        if (request.EndsOn.DayNumber - request.StartsOn.DayNumber > MaxSessionDays)
        {
            return BadRequestProblem($"Les partiels durent au maximum {MaxSessionDays} jours.");
        }

        if (request.EndsOn < clock.Today) return BadRequestProblem("Ces partiels sont déjà terminés.");
        if (request.Subjects.Count == 0) return BadRequestProblem("Choisis au moins une matière.");
        if (request.Subjects.Select(x => x.SubjectId).Distinct().Count() != request.Subjects.Count)
        {
            return BadRequestProblem("Une matière apparaît deux fois.");
        }

        var outside = request.Subjects.FirstOrDefault(x => x.ExamDay is { } day && (day < request.StartsOn || day > request.EndsOn));
        if (outside is not null) return BadRequestProblem("Une épreuve est en dehors des dates des partiels.");

        var subjectIds = request.Subjects.Select(x => x.SubjectId).ToArray();
        var known = await dbContext.Subjects.CountAsync(
            x => subjectIds.Contains(x.Id) && x.SchoolClassId == schoolClassId && x.IsActive,
            cancellationToken);
        return known == subjectIds.Length ? null : BadRequestProblem("Une des matières choisies n'existe pas dans votre classe.");
    }

    private static ExamSubject NewExamSubject(ExamSubjectRequest request, int position) => new()
    {
        SubjectId = request.SubjectId,
        ExamDay = request.ExamDay,
        StartsAt = request.StartsAt,
        Details = Clean(request.Details),
        Position = position
    };

    private Task<ExamSession?> LoadSessionAsync(Guid id, CancellationToken cancellationToken) =>
        dbContext.ExamSessions
            .AsNoTracking()
            .Include(x => x.Subjects).ThenInclude(x => x.Subject)
            .SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

    private async Task<ExamSubject?> FindVisibleSubjectAsync(Guid id, Guid schoolClassId, CancellationToken cancellationToken)
    {
        var examSubject = await dbContext.ExamSubjects
            .Include(x => x.Session)
            .Include(x => x.Subject)
            .Include(x => x.Resources)
            .AsSplitQuery()
            .SingleOrDefaultAsync(x => x.Id == id && x.Session.SchoolClassId == schoolClassId, cancellationToken);

        return examSubject is not null && IsVisible(examSubject.Session) ? examSubject : null;
    }

    private async Task<ExamSessionResponse> ToSessionResponseAsync(
        ExamSession session,
        Guid userId,
        CancellationToken cancellationToken)
    {
        var subjectIds = session.Subjects.Select(x => x.Id).ToArray();
        var items = await dbContext.RevisionItems
            .AsNoTracking()
            .Where(x => subjectIds.Contains(x.ExamSubjectId))
            .Select(x => new
            {
                x.ExamSubjectId,
                x.AuthorId,
                CheckedByMe = x.Checks.Any(check => check.UserId == userId)
            })
            .ToListAsync(cancellationToken);
        var resources = await dbContext.RevisionResources
            .AsNoTracking()
            .Where(x => subjectIds.Contains(x.ExamSubjectId))
            .Select(x => new { x.ExamSubjectId, x.AuthorId })
            .ToListAsync(cancellationToken);

        var subjects = session.Subjects
            .OrderBy(x => x.ExamDay ?? DateOnly.MaxValue)
            .ThenBy(x => x.StartsAt ?? TimeOnly.MaxValue)
            .ThenBy(x => x.Position)
            .Select(subject =>
            {
                var subjectItems = items.Where(x => x.ExamSubjectId == subject.Id).ToList();
                var subjectResources = resources.Where(x => x.ExamSubjectId == subject.Id).ToList();
                var contributors = subjectItems.Select(x => x.AuthorId)
                    .Concat(subjectResources.Select(x => x.AuthorId))
                    .Distinct()
                    .Count();

                return new ExamSubjectSummaryResponse(
                    subject.Id,
                    subject.SubjectId,
                    subject.Subject.Name,
                    subject.ExamDay,
                    subject.StartsAt,
                    subject.Details,
                    subjectItems.Count,
                    subjectItems.Count(x => x.CheckedByMe),
                    subjectResources.Count,
                    contributors);
            })
            .ToArray();

        return new ExamSessionResponse(
            session.Id,
            session.Title,
            session.StartsOn,
            session.EndsOn,
            session.OpensOn,
            session.IsOpenOn(clock.Today),
            CanContribute(session),
            subjects);
    }

    private async Task<ExamSubjectSheetResponse> ToSheetResponseAsync(
        ExamSubject examSubject,
        Guid userId,
        CancellationToken cancellationToken)
    {
        var items = await dbContext.RevisionItems
            .AsNoTracking()
            .Where(x => x.ExamSubjectId == examSubject.Id)
            .OrderBy(x => x.CreatedAt)
            .Select(x => new
            {
                Item = x,
                CheckedByMe = x.Checks.Any(check => check.UserId == userId),
                CheckCount = x.Checks.Count
            })
            .ToListAsync(cancellationToken);
        var resources = examSubject.Resources.OrderByDescending(x => x.CreatedAt).ToList();

        var authorIds = items.Select(x => x.Item.AuthorId).Concat(resources.Select(x => x.AuthorId)).Distinct().ToArray();
        var authors = await dbContext.Users
            .AsNoTracking()
            .Where(x => authorIds.Contains(x.Id))
            .ToDictionaryAsync(x => x.Id, x => AuthorName(x.FirstName, x.LastName), cancellationToken);

        return new ExamSubjectSheetResponse(
            examSubject.Id,
            examSubject.ExamSessionId,
            examSubject.Session.Title,
            examSubject.SubjectId,
            examSubject.Subject.Name,
            examSubject.ExamDay,
            examSubject.StartsAt,
            examSubject.Details,
            CanContribute(examSubject.Session),
            items.Select(x => ToItemResponse(
                x.Item,
                authors.GetValueOrDefault(x.Item.AuthorId, "Ancien élève"),
                userId,
                x.CheckedByMe,
                x.CheckCount)).ToArray(),
            resources.Select(x => ToResourceResponse(
                x,
                authors.GetValueOrDefault(x.AuthorId, "Ancien élève"),
                userId)).ToArray());
    }

    private RevisionItemResponse ToItemResponse(RevisionItem item, string authorName, Guid userId, bool checkedByMe, int checkCount) =>
        new(
            item.Id,
            item.Text,
            authorName,
            item.AuthorId == userId,
            CanModerate(item.AuthorId, userId),
            checkedByMe,
            checkCount,
            item.CreatedAt,
            item.UpdatedAt);

    private RevisionResourceResponse ToResourceResponse(RevisionResource resource, string authorName, Guid userId) =>
        new(
            resource.Id,
            resource.Kind == RevisionResourceKind.Link ? "link" : "file",
            resource.Title,
            resource.Url,
            resource.FileName,
            resource.FileType,
            resource.SizeBytes,
            authorName,
            resource.AuthorId == userId,
            CanModerate(resource.AuthorId, userId),
            resource.CreatedAt);

    private async Task<string> AuthorNameAsync(Guid authorId, CancellationToken cancellationToken)
    {
        var author = await dbContext.Users.AsNoTracking()
            .Where(x => x.Id == authorId)
            .Select(x => new { x.FirstName, x.LastName })
            .SingleOrDefaultAsync(cancellationToken);
        return author is null ? "Ancien élève" : AuthorName(author.FirstName, author.LastName);
    }

    /// <summary>« Léa M. » : le prénom suffit dans une classe, l'initiale lève les homonymes.</summary>
    private static string AuthorName(string firstName, string lastName)
    {
        var first = firstName.Trim();
        var last = lastName.Trim();
        return last.Length == 0 ? first : $"{first} {char.ToUpperInvariant(last[0])}.";
    }

    private static string? Clean(string? value)
    {
        var cleaned = value?.Trim();
        return string.IsNullOrEmpty(cleaned) ? null : cleaned;
    }
}
