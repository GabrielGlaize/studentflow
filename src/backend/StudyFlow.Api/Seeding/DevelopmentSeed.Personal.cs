using StudyFlow.Domain.Notes;
using StudyFlow.Domain.School;
using StudyFlow.Domain.Users;

namespace StudyFlow.Api.Seeding;

internal sealed partial class DevelopmentSeed
{
    private const string PersonalEventDataPurpose = "personal-event-data";
    private const string DailyNotePurpose = "daily-note-text";
    private const string ApprenticeshipMessageContentPurpose = "apprenticeship-message-content";
    private const string ApprenticeshipMessageLinkPurpose = "apprenticeship-message-link";

    private sealed record PersonalEventProtectedData(
        string Title,
        TimeOnly StartsAt,
        TimeOnly EndsAt,
        string? Location,
        string? Notes);

    /// <summary>
    /// Gabriel est en alternance chez Atelier Numérique : tâches école et entreprise, rendez-vous
    /// avec son tuteur, notes du jour. Liam cherche encore son entreprise (espace Alternance).
    /// </summary>
    private async Task SeedPersonalAsync(SchoolSeed school)
    {
        db.UserAppSettings.Add(new UserAppSettings
        {
            UserId = Gabriel.Id,
            HasCompany = true,
            CompanyName = "Atelier Numérique",
            ProfessionalMode = ProfessionalMode.Company
        });

        void Task(string title, string? description, PersonalTaskCategory category, int days, int hour, bool done = false)
        {
            var deadline = At(Today.AddDays(days), hour);
            db.PersonalTasks.Add(new PersonalTask
            {
                UserId = Gabriel.Id,
                Title = title,
                Description = description,
                Category = category,
                Deadline = deadline,
                IsDone = done,
                CompletedAt = done ? deadline.AddHours(-2) : null,
                NotificationsEnabled = true
            });
        }

        Task("Réviser les pointeurs en C", "Refaire la série 3 avant le prochain cours.", PersonalTaskCategory.School, 1, 18);
        Task("Imprimer la fiche de révision SQL", null, PersonalTaskCategory.School, 4, 8);
        Task("Livret d'alternance à faire signer", "Par le tuteur, avant la fin du mois.", PersonalTaskCategory.Company, 6, 17);
        Task("Mettre à jour la doc de l'API client", "Endpoints commandes et factures.", PersonalTaskCategory.Company, 2, 17);
        Task("Déployer la recette du site vitrine", null, PersonalTaskCategory.Company, -1, 16, done: true);

        void Event(string title, int days, int startHour, int endHour, PersonalEventCategory category, string? location, string? notes = null)
        {
            db.PersonalEvents.Add(new PersonalEvent
            {
                UserId = Gabriel.Id,
                Day = Today.AddDays(days),
                Category = category,
                EncryptedData = ProtectJson(
                    new PersonalEventProtectedData(title, new TimeOnly(startHour, 0), new TimeOnly(endHour, 0), location, notes),
                    PersonalEventDataPurpose),
                NotificationsEnabled = true
            });
        }

        // Sur des jours en entreprise : ils bloquent aussi les créneaux communs.
        var thisMonday = Today.AddDays(-(((int)Today.DayOfWeek + 6) % 7));
        Event("Point hebdo avec mon tuteur", (thisMonday.AddDays(10).DayNumber - Today.DayNumber), 9, 10, PersonalEventCategory.Company, "Atelier Numérique");
        Event("Démo client", (thisMonday.AddDays(11).DayNumber - Today.DayNumber), 14, 16, PersonalEventCategory.Company, "Visio", "Préparer la recette.");
        Event("Dentiste", 5, 18, 19, PersonalEventCategory.Personnel, "Cabinet du centre");

        // Notes du jour des trois derniers jours.
        (int DaysAgo, string Text)[] notes =
        [
            (2, "09:12 · Demander à Mme Bernard si les vues comptent dans le MCD\n17:40 · Rappeler le tuteur pour le livret"),
            (1, "11:05 · Le prof de C décale le contrôle\n14:30 · Idée : script de seed pour la démo"),
            (0, "08:50 · Penser à valider la réunion de jeudi")
        ];
        foreach (var (daysAgo, text) in notes)
        {
            db.DailyNotes.Add(new DailyNote
            {
                UserId = Gabriel.Id,
                Day = Today.AddDays(-daysAgo),
                EncryptedText = protector.Protect(text, DailyNotePurpose),
                UpdatedAt = DateTimeOffset.UtcNow.AddDays(-daysAgo)
            });
        }

        (string Author, string Content, string Link)[] messages =
        [
            ("liam", "Offre de dev web junior à Lille, ils prennent des BTS SIO en alternance.", "https://labonnealternance.apprentissage.beta.gouv.fr"),
            ("sarah", "Pensez aux mots-clés « technicien support » et « administration systèmes », il y a plus d'offres.", "https://www.francetravail.fr"),
            ("gabriel", "Mettez un petit projet sur GitHub dans vos candidatures : ça fait vraiment la différence.", "https://github.com")
        ];
        var postedAt = DateTimeOffset.UtcNow.AddDays(-5);
        foreach (var (author, content, link) in messages)
        {
            postedAt = postedAt.AddHours(20);
            db.ApprenticeshipMessages.Add(new ApprenticeshipMessage
            {
                SchoolClassId = _class.Id,
                AuthorId = _users[author].Id,
                EncryptedContent = protector.Protect(content, ApprenticeshipMessageContentPurpose),
                EncryptedLink = protector.Protect(link, ApprenticeshipMessageLinkPurpose),
                CreatedAt = postedAt
            });
        }

        await db.SaveChangesAsync();
    }
}
