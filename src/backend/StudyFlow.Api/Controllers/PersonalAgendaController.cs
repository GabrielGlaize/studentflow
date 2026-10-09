using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StudyFlow.Api.Contracts;
using StudyFlow.Application.Security;
using StudyFlow.Application.Time;
using StudyFlow.Domain.School;
using StudyFlow.Infrastructure.Identity;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/personal-agenda")]
public sealed class PersonalAgendaController(
    UserManager<ApplicationUser> userManager,
    StudyFlowDbContext dbContext,
    ISensitiveDataProtector protector,
    ISchoolClock clock) : StudyFlowControllerBase(userManager)
{
    private const string PersonalEventDataPurpose = "personal-event-data";
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    [HttpGet("tasks")]
    public async Task<ActionResult<IReadOnlyCollection<PersonalTaskResponse>>> ListTasks(
        [FromQuery] string? category,
        [FromQuery] bool includeDone = false,
        CancellationToken cancellationToken = default)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();

        var query = dbContext.PersonalTasks
            .AsNoTracking()
            .Where(x => x.UserId == user.Id);

        if (!includeDone)
        {
            query = query.Where(x => !x.IsDone);
        }

        if (!string.IsNullOrWhiteSpace(category))
        {
            var parsedCategory = ParseTaskCategory(category);
            if (parsedCategory is null) return BadRequestProblem("Catégorie de tâche invalide.");
            query = query.Where(x => x.Category == parsedCategory);
        }

        var tasks = await query
            .OrderBy(x => x.Deadline == null)
            .ThenBy(x => x.Deadline)
            .ThenBy(x => x.CreatedAt)
            .ToListAsync(cancellationToken);

        return Ok(tasks.Select(ToTaskResponse).ToArray());
    }

    [HttpPost("tasks")]
    public async Task<ActionResult<PersonalTaskResponse>> CreateTask(
        PersonalTaskRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();

        var category = ParseTaskCategory(request.Category);
        if (category is null) return BadRequestProblem("Catégorie de tâche invalide.");

        var validationProblem = await ValidateTaskRequestAsync(user, request.Title, request.CourseId, cancellationToken);
        if (validationProblem is not null) return validationProblem;
        if (!ReminderDefaults.IsValid(request.ReminderMinutesBefore)) return InvalidReminderProblem();

        var task = new PersonalTask
        {
            UserId = user.Id,
            CourseId = request.CourseId,
            Title = request.Title.Trim(),
            Description = CleanOptional(request.Description),
            Deadline = request.Deadline?.ToUniversalTime(),
            Category = category.Value,
            NotificationsEnabled = request.NotificationsEnabled,
            ReminderMinutesBefore = request.ReminderMinutesBefore
        };

        dbContext.PersonalTasks.Add(task);
        await dbContext.SaveChangesAsync(cancellationToken);

        return CreatedAtAction(nameof(GetTaskById), new { id = task.Id }, ToTaskResponse(task));
    }

    [HttpGet("tasks/{id:guid}")]
    public async Task<ActionResult<PersonalTaskResponse>> GetTaskById(Guid id, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();

        var task = await dbContext.PersonalTasks
            .AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == id && x.UserId == user.Id, cancellationToken);

        return task is null ? NotFound() : Ok(ToTaskResponse(task));
    }

    [HttpPut("tasks/{id:guid}")]
    public async Task<ActionResult<PersonalTaskResponse>> UpdateTask(
        Guid id,
        PersonalTaskUpdateRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();

        var category = ParseTaskCategory(request.Category);
        if (category is null) return BadRequestProblem("Catégorie de tâche invalide.");

        var task = await dbContext.PersonalTasks
            .SingleOrDefaultAsync(x => x.Id == id && x.UserId == user.Id, cancellationToken);
        if (task is null) return NotFound();

        var validationProblem = await ValidateTaskRequestAsync(user, request.Title, request.CourseId, cancellationToken);
        if (validationProblem is not null) return validationProblem;
        if (!ReminderDefaults.IsValid(request.ReminderMinutesBefore)) return InvalidReminderProblem();

        task.CourseId = request.CourseId;
        task.Title = request.Title.Trim();
        task.Description = CleanOptional(request.Description);
        task.Deadline = request.Deadline?.ToUniversalTime();
        task.Category = category.Value;
        task.NotificationsEnabled = request.NotificationsEnabled;
        task.ReminderMinutesBefore = request.ReminderMinutesBefore;
        task.IsDone = request.IsDone;
        task.CompletedAt = request.IsDone ? task.CompletedAt ?? DateTimeOffset.UtcNow : null;
        task.UpdatedAt = DateTimeOffset.UtcNow;

        await dbContext.SaveChangesAsync(cancellationToken);
        return Ok(ToTaskResponse(task));
    }

    [HttpDelete("tasks/{id:guid}")]
    public async Task<IActionResult> DeleteTask(Guid id, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();

        var task = await dbContext.PersonalTasks
            .SingleOrDefaultAsync(x => x.Id == id && x.UserId == user.Id, cancellationToken);
        if (task is null) return NotFound();

        dbContext.PersonalTasks.Remove(task);
        await dbContext.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    [HttpGet("events")]
    public async Task<ActionResult<IReadOnlyCollection<PersonalEventResponse>>> ListEvents(
        [FromQuery] DateOnly? from,
        [FromQuery] DateOnly? to,
        [FromQuery] string? category,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();

        var start = from ?? clock.Today.AddDays(-7);
        var end = to ?? clock.Today.AddDays(21);
        if (end < start) return BadRequestProblem("La date de fin doit etre apres la date de debut.");

        var query = dbContext.PersonalEvents
            .AsNoTracking()
            .Where(x => x.UserId == user.Id && x.Day >= start && x.Day <= end);

        if (!string.IsNullOrWhiteSpace(category))
        {
            var parsedCategory = ParseEventCategory(category);
            if (parsedCategory is null) return BadRequestProblem("Catégorie d'événement invalide.");
            query = query.Where(x => x.Category == parsedCategory);
        }

        var events = await query
            .OrderBy(x => x.Day)
            .ThenBy(x => x.CreatedAt)
            .ToListAsync(cancellationToken);

        return Ok(events.Select(ToEventResponse).OrderBy(x => x.Day).ThenBy(x => x.StartsAt).ToArray());
    }

    [HttpPost("events")]
    public async Task<ActionResult<PersonalEventResponse>> CreateEvent(
        PersonalEventRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();

        var validationProblem = ValidateEventRequest(request.Title, request.StartsAt, request.EndsAt, request.Category);
        if (validationProblem is not null) return validationProblem;
        if (!ReminderDefaults.IsValid(request.ReminderMinutesBefore)) return InvalidReminderProblem();

        var eventCategory = ParseEventCategory(request.Category)!.Value;
        var personalEvent = new PersonalEvent
        {
            UserId = user.Id,
            Day = request.Day,
            Category = eventCategory,
            NotificationsEnabled = request.NotificationsEnabled,
            ReminderMinutesBefore = request.ReminderMinutesBefore,
            EncryptedData = ProtectEventData(request.Title, request.StartsAt, request.EndsAt, request.Location, request.Notes)
        };

        dbContext.PersonalEvents.Add(personalEvent);
        await dbContext.SaveChangesAsync(cancellationToken);

        return CreatedAtAction(nameof(GetEventById), new { id = personalEvent.Id }, ToEventResponse(personalEvent));
    }

    [HttpGet("events/{id:guid}")]
    public async Task<ActionResult<PersonalEventResponse>> GetEventById(Guid id, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();

        var personalEvent = await dbContext.PersonalEvents
            .AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == id && x.UserId == user.Id, cancellationToken);

        return personalEvent is null ? NotFound() : Ok(ToEventResponse(personalEvent));
    }

    [HttpPut("events/{id:guid}")]
    public async Task<ActionResult<PersonalEventResponse>> UpdateEvent(
        Guid id,
        PersonalEventUpdateRequest request,
        CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();

        var personalEvent = await dbContext.PersonalEvents
            .SingleOrDefaultAsync(x => x.Id == id && x.UserId == user.Id, cancellationToken);
        if (personalEvent is null) return NotFound();

        var validationProblem = ValidateEventRequest(request.Title, request.StartsAt, request.EndsAt, request.Category);
        if (validationProblem is not null) return validationProblem;
        if (!ReminderDefaults.IsValid(request.ReminderMinutesBefore)) return InvalidReminderProblem();

        personalEvent.Day = request.Day;
        personalEvent.Category = ParseEventCategory(request.Category)!.Value;
        personalEvent.NotificationsEnabled = request.NotificationsEnabled;
        personalEvent.ReminderMinutesBefore = request.ReminderMinutesBefore;
        personalEvent.EncryptedData = ProtectEventData(request.Title, request.StartsAt, request.EndsAt, request.Location, request.Notes);
        personalEvent.UpdatedAt = DateTimeOffset.UtcNow;

        await dbContext.SaveChangesAsync(cancellationToken);
        return Ok(ToEventResponse(personalEvent));
    }

    [HttpDelete("events/{id:guid}")]
    public async Task<IActionResult> DeleteEvent(Guid id, CancellationToken cancellationToken)
    {
        var user = await CurrentUserAsync();
        if (user is null) return Unauthorized();

        var personalEvent = await dbContext.PersonalEvents
            .SingleOrDefaultAsync(x => x.Id == id && x.UserId == user.Id, cancellationToken);
        if (personalEvent is null) return NotFound();

        dbContext.PersonalEvents.Remove(personalEvent);
        await dbContext.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    private ObjectResult InvalidReminderProblem() =>
        BadRequestProblem("Le rappel doit être programmé entre le moment même et 30 jours avant.");

    private async Task<ActionResult?> ValidateTaskRequestAsync(
        ApplicationUser user,
        string title,
        Guid? courseId,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(title))
        {
            return BadRequestProblem("Le titre de la tâche est obligatoire.");
        }

        if (courseId is null)
        {
            return null;
        }

        // Un futur eleve sans classe peut utiliser son agenda, mais ne peut pas lier une tache a un cours.
        if (user.SchoolClassId is null)
        {
            return BadRequestProblem("Rejoins une classe pour lier une tâche à un cours.");
        }

        var courseExists = await dbContext.Courses.AnyAsync(
            x => x.Id == courseId
                && x.SchoolClassId == user.SchoolClassId
                && x.DeletedAt == null,
            cancellationToken);

        return courseExists
            ? null
            : BadRequestProblem("Le cours lié à la tâche n'existe pas dans ta classe.");
    }

    private ActionResult? ValidateEventRequest(string title, TimeOnly startsAt, TimeOnly endsAt, string category)
    {
        if (string.IsNullOrWhiteSpace(title))
        {
            return BadRequestProblem("Le titre de l'événement est obligatoire.");
        }

        if (endsAt <= startsAt)
        {
            return BadRequestProblem("L'heure de fin doit être après l'heure de début.");
        }

        return ParseEventCategory(category) is null
            ? BadRequestProblem("Catégorie d'événement invalide.")
            : null;
    }

    private PersonalTaskResponse ToTaskResponse(PersonalTask task) => new(
        task.Id,
        task.Title,
        task.Description,
        task.Deadline,
        ToTaskCategoryName(task.Category),
        task.IsDone,
        task.NotificationsEnabled,
        task.CourseId,
        task.CreatedAt,
        task.UpdatedAt,
        task.ReminderMinutesBefore);

    private PersonalEventResponse ToEventResponse(PersonalEvent personalEvent)
    {
        var data = JsonSerializer.Deserialize<PersonalEventProtectedData>(
            protector.Unprotect(personalEvent.EncryptedData, PersonalEventDataPurpose),
            JsonOptions)!;

        return new PersonalEventResponse(
            personalEvent.Id,
            data.Title,
            personalEvent.Day,
            data.StartsAt,
            data.EndsAt,
            ToEventCategoryName(personalEvent.Category),
            data.Location,
            data.Notes,
            personalEvent.NotificationsEnabled,
            personalEvent.CreatedAt,
            personalEvent.UpdatedAt,
            personalEvent.ReminderMinutesBefore);
    }

    private string ProtectEventData(
        string title,
        TimeOnly startsAt,
        TimeOnly endsAt,
        string? location,
        string? notes)
    {
        // Le contenu precis de l'agenda personnel est chiffre : il ne doit pas etre lisible directement en base.
        var data = new PersonalEventProtectedData(
            title.Trim(),
            startsAt,
            endsAt,
            CleanOptional(location),
            CleanOptional(notes));

        return protector.Protect(JsonSerializer.Serialize(data, JsonOptions), PersonalEventDataPurpose);
    }

    private static PersonalTaskCategory? ParseTaskCategory(string value) =>
        value.Trim().ToLowerInvariant() switch
        {
            "school" => PersonalTaskCategory.School,
            "apprenticeship" => PersonalTaskCategory.Apprenticeship,
            "alternance" => PersonalTaskCategory.Apprenticeship,
            "company" => PersonalTaskCategory.Company,
            _ => null
        };

    private static string ToTaskCategoryName(PersonalTaskCategory category) =>
        category switch
        {
            PersonalTaskCategory.School => "school",
            PersonalTaskCategory.Apprenticeship => "apprenticeship",
            PersonalTaskCategory.Company => "company",
            _ => "school"
        };

    private static PersonalEventCategory? ParseEventCategory(string value) =>
        value.Trim().ToLowerInvariant() switch
        {
            "apprenticeship" => PersonalEventCategory.Apprenticeship,
            "alternance" => PersonalEventCategory.Apprenticeship,
            "company" => PersonalEventCategory.Company,
            "personal" => PersonalEventCategory.Personnel,
            _ => null
        };

    private static string ToEventCategoryName(PersonalEventCategory category) =>
        category switch
        {
            PersonalEventCategory.Apprenticeship => "apprenticeship",
            PersonalEventCategory.Company => "company",
            PersonalEventCategory.Personnel => "personal",
            _ => "personal"
        };

    private static string? CleanOptional(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private sealed record PersonalEventProtectedData(
        string Title,
        TimeOnly StartsAt,
        TimeOnly EndsAt,
        string? Location,
        string? Notes);
}
