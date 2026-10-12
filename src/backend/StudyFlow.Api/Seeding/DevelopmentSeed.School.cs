using StudyFlow.Domain.School;

namespace StudyFlow.Api.Seeding;

internal sealed partial class DevelopmentSeed
{
    private const string CourseDataPurpose = "course-data";
    private const string TeacherDisplayPurpose = "teacher-display-name";
    private const string TeacherLookupPurpose = "teacher-search-name";
    private const string TeacherInfoPurpose = "teacher-information";

    /// <summary>Ce que les étapes suivantes réutilisent : matières, cours posés et devoirs.</summary>
    private sealed record SchoolSeed(
        Dictionary<string, Subject> Subjects,
        List<SeededCourse> Courses,
        Dictionary<string, Homework> Homework);

    private sealed record SeededCourse(Course Course, string Subject, TimeOnly StartsAt, TimeOnly EndsAt);

    private sealed record CourseSlot(string Subject, string? Teacher, int StartHour, int StartMinute, int EndHour, int EndMinute, string Room);

    private sealed record CourseProtectedData(TimeOnly StartsAt, TimeOnly EndsAt, string Room);

    /// <summary>Matière → intervenant et sa description.</summary>
    private static readonly (string Subject, string? Teacher, string? Info)[] Catalog =
    [
        ("Flutter", "Mme Dupont", "Développement mobile, référente du projet annuel"),
        ("API ASP.NET Core", "M. Martin", "API REST, sécurité et architecture"),
        ("Base de données", "Mme Bernard", "SQL, modélisation Merise"),
        ("C", "M. Mahieux", "Langage C et algorithmique"),
        ("Architecture web", "M. Vaast", "Conception client / serveur"),
        ("HTML/CSS/JS", "M. Debureau", "Intégration et JavaScript"),
        ("Administration Windows", "M. Alexandre", "Active Directory, droits NTFS"),
        ("Anglais", "Ms Carter", "Anglais professionnel, oraux"),
        ("Culture générale", null, null)
    ];

    /// <summary>
    /// Emploi du temps type de l'alternance : lundi et mardi à l'école chaque semaine, le
    /// mercredi une semaine sur deux ; le reste du temps en entreprise.
    /// </summary>
    private static readonly Dictionary<DayOfWeek, CourseSlot[]> Timetable = new()
    {
        [DayOfWeek.Monday] =
        [
            new("Flutter", "Mme Dupont", 9, 0, 12, 0, "B204"),
            new("Base de données", "Mme Bernard", 13, 30, 15, 30, "C301"),
            new("Anglais", "Ms Carter", 15, 45, 17, 15, "B112")
        ],
        [DayOfWeek.Tuesday] =
        [
            new("C", "M. Mahieux", 8, 30, 10, 30, "B204"),
            new("Architecture web", "M. Vaast", 10, 45, 12, 15, "A102"),
            new("API ASP.NET Core", "M. Martin", 13, 30, 16, 30, "A102")
        ],
        [DayOfWeek.Wednesday] =
        [
            new("HTML/CSS/JS", "M. Debureau", 9, 0, 12, 0, "C205"),
            new("Administration Windows", "M. Alexandre", 13, 30, 15, 30, "B112"),
            new("Culture générale", null, 15, 45, 17, 0, "Amphi")
        ]
    };

    private async Task<SchoolSeed> SeedSchoolAsync()
    {
        var subjects = new Dictionary<string, Subject>();
        var teachers = new Dictionary<string, Teacher>();
        foreach (var (subjectName, teacherName, info) in Catalog)
        {
            var subject = new Subject { SchoolClassId = _class.Id, Name = subjectName, CreatedById = Gabriel.Id };
            subjects[subjectName] = subject;
            db.Subjects.Add(subject);
            if (teacherName is null) continue;

            var teacher = new Teacher
            {
                SchoolClassId = _class.Id,
                EncryptedDisplayName = protector.Protect(teacherName, TeacherDisplayPurpose),
                SearchNameHash = protector.ComputeLookupHash(teacherName, TeacherLookupPurpose),
                EncryptedInformation = info is null ? null : protector.Protect(info, TeacherInfoPurpose),
                CreatedById = Gabriel.Id
            };
            teachers[teacherName] = teacher;
            db.Teachers.Add(teacher);
            db.SubjectTeachers.Add(new SubjectTeacher { Subject = subject, Teacher = teacher });
        }

        // Deux semaines passées, la semaine en cours et deux à venir.
        var courses = new List<SeededCourse>();
        var thisMonday = Today.AddDays(-(((int)Today.DayOfWeek + 6) % 7));
        for (var week = -2; week <= 2; week++)
        {
            var monday = thisMonday.AddDays(7 * week);
            foreach (var (dayOfWeek, slots) in Timetable)
            {
                if (dayOfWeek == DayOfWeek.Wednesday && week % 2 != 0) continue;
                var day = monday.AddDays(((int)dayOfWeek + 6) % 7);
                foreach (var slot in slots)
                {
                    var startsAt = new TimeOnly(slot.StartHour, slot.StartMinute);
                    var endsAt = new TimeOnly(slot.EndHour, slot.EndMinute);
                    var course = new Course
                    {
                        SchoolClassId = _class.Id,
                        Subject = subjects[slot.Subject],
                        Teacher = slot.Teacher is null ? null : teachers[slot.Teacher],
                        Day = day,
                        EncryptedData = ProtectJson(new CourseProtectedData(startsAt, endsAt, slot.Room), CourseDataPurpose),
                        CreatedById = Gabriel.Id
                    };
                    db.Courses.Add(course);
                    courses.Add(new SeededCourse(course, slot.Subject, startsAt, endsAt));
                }
            }
        }

        // Prof absent la semaine prochaine : le cours reste visible, barré.
        var cancelled = NextCourse(courses, "C", Today.AddDays(7));
        if (cancelled is not null) cancelled.Course.IsCancelled = true;

        await db.SaveChangesAsync();

        var homework = SeedHomework(courses);
        SeedAnnouncements();
        await db.SaveChangesAsync();

        return new SchoolSeed(subjects, courses, homework);
    }

    /// <summary>Le premier cours de la matière à partir de ce jour (devoir « pour le prochain cours »).</summary>
    private static SeededCourse? NextCourse(IEnumerable<SeededCourse> courses, string subject, DateOnly from) =>
        courses
            .Where(x => x.Subject == subject && x.Course.Day >= from && !x.Course.IsCancelled)
            .OrderBy(x => x.Course.Day)
            .FirstOrDefault();

    private Dictionary<string, Homework> SeedHomework(List<SeededCourse> courses)
    {
        var homework = new Dictionary<string, Homework>();

        void Add(string key, string subject, int fromDays, string title, string description, bool evaluation = false, bool groupWork = false)
        {
            var course = NextCourse(courses, subject, Today.AddDays(fromDays));
            if (course is null) return;

            var item = new Homework
            {
                SchoolClassId = _class.Id,
                CourseId = course.Course.Id,
                Title = title,
                Description = description,
                Deadline = At(course.Course.Day, course.StartsAt.Hour, course.StartsAt.Minute),
                IsEvaluation = evaluation,
                IsGroupWork = groupWork,
                CreatedById = (homework.Count % 3 == 0 ? Gabriel : _users["garance"]).Id
            };
            homework[key] = item;
            db.HomeworkItems.Add(item);
        }

        Add("flutter-maquette", "Flutter", 1, "Maquette Flutter : écrans principaux",
            "Accueil, planning et profil. Captures dans le dépôt GitHub du projet.");
        Add("c-pointeurs", "C", 1, "Exercices C : pointeurs et tableaux",
            "Série 4, exercices 1 à 6. Rendre le .c compilé sans warning.");
        Add("sql-controle", "Base de données", 6, "Contrôle SQL : jointures",
            "Jointures internes et externes, GROUP BY. Calculatrice interdite.", evaluation: true);
        Add("bdd-projet", "Base de données", 13, "Projet BDD : médiathèque",
            "Par groupes de 3 : MCD, MLD, script SQL de création et jeu de données. Soutenance de 10 minutes.",
            groupWork: true);
        Add("reseau-dossier", "Administration Windows", 8, "Dossier réseau : domaine Active Directory",
            "Par groupes de 2 ou 3 : maquette d'un domaine, GPO et partages. Rapport PDF.", groupWork: true);
        Add("anglais-oral", "Anglais", 6, "Oral d'anglais : présente ton entreprise",
            "3 minutes, sans notes. Une diapositive maximum.", evaluation: true);
        Add("api-cr", "API ASP.NET Core", -9, "Compte-rendu : authentification JWT",
            "Expliquer access token, refresh token et leur durée de vie.");

        Add("bdd-exercices", "Base de données", -13, "Exercices SQL : requêtes simples",
            "Feuille 2, requêtes 1 à 12 sur la base « bibliothèque ».");
        Add("anglais-cv", "Anglais", -13, "CV en anglais",
            "Une page, format Europass accepté.");

        // Les devoirs passés sont rendus par toute la classe, sauf Yanis (situation « en retard »).
        var past = homework.Values.Where(x => x.Deadline < DateTimeOffset.UtcNow).ToList();
        var onTime = DevelopmentAccounts.All.Where(x => x.InClass && x.Key != "yanis").Select(x => _users[x.Key]);
        foreach (var item in past)
        {
            foreach (var student in onTime)
            {
                db.HomeworkProgressItems.Add(new HomeworkProgress
                {
                    Homework = item,
                    UserId = student.Id,
                    IsDone = true,
                    CompletedAt = item.Deadline.AddDays(-1)
                });
            }
        }

        return homework;
    }

    private void SeedAnnouncements()
    {
        (string Content, bool Pinned, int DaysAgo)[] announcements =
        [
            ("Partiels du semestre 1 : la fiche de révision est ouverte, complétez-la ensemble.", true, 1),
            ("Lundi, le cours de Flutter a lieu en B204 (la salle C301 est en travaux).", true, 2),
            ("Projet BDD : formez vos groupes de 3 avant mercredi, depuis le devoir dans l'agenda.", false, 3),
            ("Pensez à faire signer votre livret d'alternance par votre tuteur avant la fin du mois.", false, 6)
        ];

        foreach (var (content, pinned, daysAgo) in announcements)
        {
            var at = DateTimeOffset.UtcNow.AddDays(-daysAgo);
            db.ClassAnnouncements.Add(new ClassAnnouncement
            {
                SchoolClassId = _class.Id,
                AuthorId = Gabriel.Id,
                Content = content,
                IsPinned = pinned,
                CreatedAt = at,
                UpdatedAt = at
            });
        }
    }
}
