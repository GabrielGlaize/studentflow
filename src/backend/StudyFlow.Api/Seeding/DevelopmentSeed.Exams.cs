using StudyFlow.Domain.Exams;

namespace StudyFlow.Api.Seeding;

internal sealed partial class DevelopmentSeed
{
    /// <summary>
    /// Partiels dans deux semaines : la fiche de révision est déjà ouverte et commencée par
    /// plusieurs élèves (points à revoir, liens), avec quelques cases cochées par Gabriel.
    /// </summary>
    private async Task SeedExamsAsync(SchoolSeed school)
    {
        var thisMonday = Today.AddDays(-(((int)Today.DayOfWeek + 6) % 7));
        var startsOn = thisMonday.AddDays(14);
        var session = new ExamSession
        {
            SchoolClassId = _class.Id,
            Title = "Partiels du semestre 1",
            StartsOn = startsOn,
            EndsOn = startsOn.AddDays(3),
            CreatedById = Gabriel.Id
        };

        (string Subject, int Day, int Hour, string Details, (string Author, string Text, bool GabrielChecked)[] Items, (string Author, string Title, string Url)[] Links)[] plan =
        [
            ("Base de données", 0, 9, "2 h · sans document",
            [
                ("garance", "Passer d'un MCD à un MLD (cardinalités 1,n et 0,n)", true),
                ("liam", "Jointures externes : LEFT JOIN vs RIGHT JOIN", true),
                ("ines", "GROUP BY + HAVING, piège du COUNT(*)", false),
                ("gabriel", "Contraintes : clé étrangère, ON DELETE CASCADE", false)
            ],
            [("ines", "Cours SQL interactif", "https://sqlbolt.com")]),
            ("Flutter", 1, 9, "3 h · sur machine, documentation autorisée",
            [
                ("gabriel", "StatefulWidget : cycle de vie et setState", true),
                ("yanis", "Navigation : push, pop et passage de résultat", false),
                ("chloe", "FutureBuilder et états chargement / erreur", false)
            ],
            [("yanis", "Documentation Flutter : widgets", "https://docs.flutter.dev/ui/widgets")]),
            ("C", 2, 14, "2 h · papier",
            [
                ("hugo", "Pointeurs de pointeurs et tableaux 2D", false),
                ("sarah", "malloc / free : qui libère quoi", false)
            ],
            []),
            ("Anglais", 3, 10, "Oral 10 min · présentation de l'entreprise d'alternance",
            [
                ("garance", "Vocabulaire : job description, tasks, team", false)
            ],
            [])
        ];

        var position = 0;
        foreach (var (subjectName, day, hour, details, items, links) in plan)
        {
            var examSubject = new ExamSubject
            {
                Session = session,
                SubjectId = school.Subjects[subjectName].Id,
                ExamDay = startsOn.AddDays(day),
                StartsAt = new TimeOnly(hour, 0),
                Details = details,
                Position = position++
            };
            session.Subjects.Add(examSubject);

            foreach (var (author, text, gabrielChecked) in items)
            {
                var item = new RevisionItem { ExamSubject = examSubject, AuthorId = _users[author].Id, Text = text };
                if (gabrielChecked) item.Checks.Add(new RevisionItemCheck { UserId = Gabriel.Id });
                examSubject.Items.Add(item);
            }

            foreach (var (author, title, url) in links)
            {
                examSubject.Resources.Add(new RevisionResource
                {
                    ExamSubject = examSubject,
                    AuthorId = _users[author].Id,
                    Kind = RevisionResourceKind.Link,
                    Title = title,
                    Url = url
                });
            }
        }

        db.ExamSessions.Add(session);
        await db.SaveChangesAsync();
    }
}
