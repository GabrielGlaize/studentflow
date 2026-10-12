using StudyFlow.Api.Controllers;
using StudyFlow.Api.Realtime;
using StudyFlow.Domain.Groups;
using StudyFlow.Domain.School;
using StudyFlow.Infrastructure.Identity;

namespace StudyFlow.Api.Seeding;

internal sealed partial class DevelopmentSeed
{
    private const string GroupTextPurpose = "study-group-text";
    private const string GroupTaskPurpose = "study-group-task";

    /// <summary>
    /// Trois groupes : celui de Gabriel pour le projet BDD (discussion, tâches, une réunion
    /// confirmée et une à valider), un autre groupe du même projet (pour voir qui est déjà
    /// pris), et le groupe de Hugo pour le dossier réseau, qui attend la réponse de Gabriel.
    /// Sarah n'a de groupe pour aucun des deux travaux.
    /// </summary>
    private async Task SeedGroupsAsync(SchoolSeed school)
    {
        var now = DateTimeOffset.UtcNow;
        var bddProject = school.Homework.GetValueOrDefault("bdd-projet");
        var networkFile = school.Homework.GetValueOrDefault("reseau-dossier");

        // ── Projet BDD — équipe 1 : le groupe de Gabriel ───────────────────────────
        var team1 = NewGroup("Projet BDD — équipe 1", bddProject, school.Subjects["Base de données"].Id,
            "Médiathèque : MCD validé avant le contrôle, script SQL et soutenance de 10 minutes.", now.AddDays(-4));
        AddMember(team1, "gabriel", StudyGroupRole.Organizer, "SQL", now.AddDays(-4));
        AddMember(team1, "garance", StudyGroupRole.Member, "Rédaction", now.AddDays(-4));
        AddMember(team1, "liam", StudyGroupRole.Member, "Diapos", now.AddDays(-3));

        AddTask(team1, "MCD validé par Mme Bernard", ["garance", "gabriel"], StudyGroupTaskStatus.Done, Today.AddDays(-1));
        AddTask(team1, "Script SQL de création des tables", ["gabriel"], StudyGroupTaskStatus.Doing, Today.AddDays(3),
            "Penser aux contraintes ON DELETE pour les emprunts.");
        AddTask(team1, "Jeu de données : 30 livres, 10 adhérents", ["garance"], StudyGroupTaskStatus.Todo, Today.AddDays(5));
        AddTask(team1, "Diapos de la soutenance", ["liam"], StudyGroupTaskStatus.Todo, Today.AddDays(10));
        AddTask(team1, "Répétition générale", [], StudyGroupTaskStatus.Todo, Today.AddDays(12));

        AddMessage(team1, null, $"{ShortName(Gabriel)} a créé le groupe.", now.AddDays(-4));
        AddMessage(team1, null, $"{ShortName(_users["garance"])} a rejoint le groupe.", now.AddDays(-4).AddMinutes(20));
        AddMessage(team1, null, $"{ShortName(_users["liam"])} a rejoint le groupe.", now.AddDays(-3));
        AddMessage(team1, "garance", "J'ai mis le MCD dans les fichiers, dites-moi si les cardinalités vous vont", now.AddHours(-26));
        AddMessage(team1, "gabriel", "Top, je commence le script SQL ce soir après le taf", now.AddHours(-25));
        AddMessage(team1, "liam", "Je prends les diapos. On se cale un point lundi midi ?", now.AddHours(-3));
        AddMessage(team1, "garance", "Ok pour lundi, j'ai proposé aussi jeudi soir en visio", now.AddMinutes(-40));
        team1.Members.Single(x => x.UserId == Gabriel.Id).LastReadAt = now.AddHours(-24);

        var nextMonday = Today.AddDays(7 - (((int)Today.DayOfWeek + 6) % 7));
        AddMeeting(team1, nextMonday, 12, 15, 60, StudyGroupMeetingMode.OnSite, "Salle C301", "liam",
            StudyGroupMeetingStatus.Confirmed, ["liam", "gabriel", "garance"]);
        AddMeeting(team1, nextMonday.AddDays(3), 19, 0, 60, StudyGroupMeetingMode.Remote, "Visio Discord", "garance",
            StudyGroupMeetingStatus.Proposed, ["garance", "liam"]);

        db.StudyGroupResources.AddRange(
            NewLink(team1, "garance", "MCD sur draw.io", "https://app.diagrams.net/", now.AddHours(-26)),
            NewLink(team1, "liam", "Modèle de diapos", "https://www.canva.com/", now.AddHours(-3)));

        // ── Projet BDD — équipe 2 : un autre groupe, privé pour Gabriel ────────────
        var team2 = NewGroup("Projet BDD — équipe 2", bddProject, school.Subjects["Base de données"].Id, null, now.AddDays(-2));
        AddMember(team2, "ines", StudyGroupRole.Organizer, null, now.AddDays(-2));
        AddMember(team2, "yanis", StudyGroupRole.Member, null, now.AddDays(-2));
        AddMember(team2, "chloe", StudyGroupRole.Member, "Rédaction", now.AddDays(-1));
        AddTask(team2, "Choisir le sujet de la base", ["ines"], StudyGroupTaskStatus.Done, Today.AddDays(-1));
        AddTask(team2, "MCD", ["yanis", "chloe"], StudyGroupTaskStatus.Doing, Today.AddDays(2));
        AddMessage(team2, null, $"{ShortName(_users["ines"])} a créé le groupe.", now.AddDays(-2));
        AddMessage(team2, "yanis", "On part sur une base de location de vélos ?", now.AddDays(-1));

        // ── Dossier réseau : Hugo, seul, invite Gabriel ─────────────────────────────
        var network = NewGroup("Dossier réseau", networkFile, school.Subjects["Administration Windows"].Id,
            "Domaine AD avec deux OU, trois GPO et un partage par service.", now.AddHours(-5));
        AddMember(network, "hugo", StudyGroupRole.Organizer, null, now.AddHours(-5));
        network.Members.Add(new StudyGroupMember
        {
            UserId = Gabriel.Id,
            Role = StudyGroupRole.Member,
            Status = StudyGroupMemberStatus.Invited,
            InvitedById = _users["hugo"].Id,
            InvitedAt = now.AddHours(-2)
        });
        AddMessage(network, null, $"{ShortName(_users["hugo"])} a créé le groupe.", now.AddHours(-5));

        db.StudyGroups.AddRange(team1, team2, network);

        // Disponibilités : Gabriel n'a rien déclaré (l'app le lui propose), les autres oui.
        db.UserAvailabilities.AddRange(
            new UserAvailability { UserId = _users["garance"].Id, CompanyEndsAt = new TimeOnly(17, 0) },
            new UserAvailability { UserId = _users["liam"].Id, CompanyEndsAt = new TimeOnly(18, 0), WeekendAvailable = true });

        await db.SaveChangesAsync();
    }

    private StudyGroup NewGroup(string name, Homework? homework, Guid subjectId, string? description, DateTimeOffset createdAt) => new()
    {
        SchoolClassId = _class.Id,
        Name = name,
        HomeworkId = homework?.Id,
        DueAt = homework?.Deadline,
        SubjectId = subjectId,
        EncryptedDescription = description is null ? null : protector.Protect(description, GroupTextPurpose),
        CreatedById = null,
        CreatedAt = createdAt,
        UpdatedAt = createdAt
    };

    private void AddMember(StudyGroup group, string key, StudyGroupRole role, string? roleLabel, DateTimeOffset joinedAt)
    {
        group.CreatedById ??= _users[key].Id;
        group.Members.Add(new StudyGroupMember
        {
            UserId = _users[key].Id,
            Role = role,
            Status = StudyGroupMemberStatus.Active,
            RoleLabel = roleLabel,
            InvitedAt = joinedAt,
            JoinedAt = joinedAt,
            LastReadAt = DateTimeOffset.UtcNow
        });
    }

    private void AddTask(StudyGroup group, string title, string[] assignees, StudyGroupTaskStatus status, DateOnly dueOn, string? notes = null)
    {
        var task = new StudyGroupTask
        {
            EncryptedTitle = protector.Protect(title, GroupTaskPurpose),
            EncryptedNotes = notes is null ? null : protector.Protect(notes, GroupTaskPurpose),
            Status = status,
            DueOn = dueOn,
            CreatedById = group.CreatedById,
            CompletedAt = status == StudyGroupTaskStatus.Done ? DateTimeOffset.UtcNow.AddDays(-1) : null
        };
        foreach (var key in assignees) task.Assignees.Add(new StudyGroupTaskAssignee { UserId = _users[key].Id });
        group.Tasks.Add(task);
    }

    private void AddMessage(StudyGroup group, string? author, string text, DateTimeOffset at) =>
        db.StudyGroupMessages.Add(new StudyGroupMessage
        {
            Group = group,
            AuthorId = author is null ? null : _users[author].Id,
            EncryptedText = protector.Protect(text, StudyGroupNotifier.MessagePurpose),
            CreatedAt = at
        });

    private void AddMeeting(
        StudyGroup group,
        DateOnly day,
        int hour,
        int minute,
        int minutes,
        StudyGroupMeetingMode mode,
        string place,
        string proposedBy,
        StudyGroupMeetingStatus status,
        string[] yes)
    {
        var startsAt = At(day, hour, minute);
        var meeting = new StudyGroupMeeting
        {
            Group = group,
            StartsAt = startsAt,
            EndsAt = startsAt.AddMinutes(minutes),
            Mode = mode,
            EncryptedPlace = protector.Protect(place, GroupTextPurpose),
            ProposedById = _users[proposedBy].Id,
            Status = status
        };
        foreach (var key in yes) meeting.Votes.Add(new StudyGroupMeetingVote { UserId = _users[key].Id, IsAvailable = true });
        db.StudyGroupMeetings.Add(meeting);
    }

    private StudyGroupResource NewLink(StudyGroup group, string author, string title, string url, DateTimeOffset at) => new()
    {
        Group = group,
        AuthorId = _users[author].Id,
        Kind = StudyGroupResourceKind.Link,
        EncryptedTitle = protector.Protect(title, GroupTextPurpose),
        EncryptedUrl = protector.Protect(url, GroupTextPurpose),
        CreatedAt = at,
        UpdatedAt = at
    };

    /// <summary>Même format que l'app : « Léa M. ».</summary>
    private static string ShortName(ApplicationUser user) => StudentNames.Short(user.FirstName, user.LastName);
}
