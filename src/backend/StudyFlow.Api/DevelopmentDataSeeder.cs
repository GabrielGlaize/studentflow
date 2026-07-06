using System.Text.Json;
using System.Security.Cryptography;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using StudyFlow.Application.Security;
using StudyFlow.Domain.School;
using StudyFlow.Domain.Users;
using StudyFlow.Infrastructure.Identity;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Api;

public static class DevelopmentDataSeeder
{
    private const string DelegateEmail = "gabriel@studyflow.dev";
    private const string DelegatePassword = "Password1234!";
    private const string CourseDataPurpose = "course-data";
    private const string TeacherDisplayPurpose = "teacher-display-name";
    private const string TeacherLookupPurpose = "teacher-search-name";
    private const string TeacherInfoPurpose = "teacher-information";
    private const string ApprenticeshipMessageContentPurpose = "apprenticeship-message-content";
    private const string ApprenticeshipMessageLinkPurpose = "apprenticeship-message-link";
    private const string PersonalEventDataPurpose = "personal-event-data";

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public static async Task SeedDevelopmentDataAsync(this IServiceProvider services)
    {
        using var scope = services.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<StudyFlowDbContext>();
        var configuration = scope.ServiceProvider.GetRequiredService<IConfiguration>();
        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var classCodeService = scope.ServiceProvider.GetRequiredService<IClassCodeService>();
        var protector = scope.ServiceProvider.GetRequiredService<ISensitiveDataProtector>();
        var logger = scope.ServiceProvider
            .GetRequiredService<ILoggerFactory>()
            .CreateLogger(nameof(DevelopmentDataSeeder));

        if (configuration.GetValue<bool>("DevelopmentSeed:ResetOnStartup"))
        {
            logger.LogWarning(
                "DevelopmentSeed:ResetOnStartup=true. The local development database will be deleted and recreated.");
            await dbContext.Database.EnsureDeletedAsync();
        }

        await dbContext.Database.MigrateAsync();

        var delegateUser = await userManager.FindByEmailAsync(DelegateEmail);
        if (delegateUser is null)
        {
            delegateUser = new ApplicationUser
            {
                Id = Guid.NewGuid(),
                UserName = DelegateEmail,
                Email = DelegateEmail,
                FirstName = "Gabriel",
                LastName = "Glz"
            };

            var createResult = await userManager.CreateAsync(delegateUser, DelegatePassword);
            if (!createResult.Succeeded)
            {
                throw new InvalidOperationException(
                    $"Impossible de créer l'utilisateur dev : {string.Join(", ", createResult.Errors.Select(x => x.Description))}");
            }
        }

        await EnsureRoleAsync(userManager, delegateUser, nameof(UserRole.Eleve));
        await EnsureRoleAsync(userManager, delegateUser, nameof(UserRole.Delegue));
        await EnsureDevelopmentPasswordAsync(userManager, delegateUser);

        var schoolClass = await dbContext.SchoolClasses
            .Include(x => x.Subjects)
            .Include(x => x.Teachers)
            .SingleOrDefaultAsync(x => x.Name == "BTS SIO 1");

        if (schoolClass is null)
        {
            var code = classCodeService.Generate();
            schoolClass = new SchoolClass
            {
                Name = "BTS SIO 1",
                SchoolYear = "2026-2027",
                AccessCodeHash = code.Hash,
                EncryptedAccessCode = code.Ciphertext,
                AccessCodeUpdatedAt = DateTimeOffset.UtcNow,
                CreatedById = delegateUser.Id
            };

            dbContext.SchoolClasses.Add(schoolClass);
            delegateUser.SchoolClassId = schoolClass.Id;
            await dbContext.SaveChangesAsync();
            await userManager.UpdateAsync(delegateUser);
        }
        else if (delegateUser.SchoolClassId != schoolClass.Id)
        {
            delegateUser.SchoolClassId = schoolClass.Id;
            await userManager.UpdateAsync(delegateUser);
        }

        await EnsureStudentAsync(userManager, schoolClass.Id, "garance@studyflow.dev", "Garance", "Moreau");
        await EnsureStudentAsync(userManager, schoolClass.Id, "liam@studyflow.dev", "Liam", "Petit");
        await EnsurePendingStudentRequestAsync(userManager, dbContext, schoolClass.Id, "nina@studyflow.dev", "Nina", "Lemoine");

        var subjects = await EnsureSubjectsAsync(dbContext, schoolClass.Id, delegateUser.Id);
        var teachers = await EnsureTeachersAsync(dbContext, protector, schoolClass.Id, delegateUser.Id);
        await EnsureCoursesAsync(dbContext, protector, schoolClass.Id, delegateUser.Id, subjects, teachers);
        await EnsureHomeworkAsync(dbContext, schoolClass.Id, delegateUser.Id);
        await EnsureAnnouncementsAsync(dbContext, schoolClass.Id, delegateUser.Id);
        await EnsurePersonalAgendaAsync(dbContext, protector, delegateUser.Id);
        await EnsureApprenticeshipMessagesAsync(dbContext, protector, schoolClass.Id, delegateUser.Id);

        LogDevelopmentAccounts(logger, classCodeService.Reveal(schoolClass.EncryptedAccessCode));
    }

    private static async Task EnsureStudentAsync(
        UserManager<ApplicationUser> userManager,
        Guid schoolClassId,
        string email,
        string firstName,
        string lastName)
    {
        var student = await userManager.FindByEmailAsync(email);
        if (student is null)
        {
            student = new ApplicationUser
            {
                Id = Guid.NewGuid(),
                UserName = email,
                Email = email,
                FirstName = firstName,
                LastName = lastName,
                SchoolClassId = schoolClassId
            };

            var createResult = await userManager.CreateAsync(student, DelegatePassword);
            if (!createResult.Succeeded)
            {
                throw new InvalidOperationException(
                    $"Impossible de créer l'élève dev {email} : {string.Join(", ", createResult.Errors.Select(x => x.Description))}");
            }
        }
        else if (student.SchoolClassId != schoolClassId)
        {
            student.SchoolClassId = schoolClassId;
            await userManager.UpdateAsync(student);
        }

        await EnsureDevelopmentPasswordAsync(userManager, student);
        await EnsureRoleAsync(userManager, student, nameof(UserRole.Eleve));
    }

    private static async Task EnsurePendingStudentRequestAsync(
        UserManager<ApplicationUser> userManager,
        StudyFlowDbContext dbContext,
        Guid schoolClassId,
        string email,
        string firstName,
        string lastName)
    {
        var student = await userManager.FindByEmailAsync(email);
        if (student is null)
        {
            student = new ApplicationUser
            {
                Id = Guid.NewGuid(),
                UserName = email,
                Email = email,
                FirstName = firstName,
                LastName = lastName
            };

            var createResult = await userManager.CreateAsync(student, DelegatePassword);
            if (!createResult.Succeeded)
            {
                throw new InvalidOperationException(
                    $"Impossible de créer l'élève en attente dev {email} : {string.Join(", ", createResult.Errors.Select(x => x.Description))}");
            }
        }

        // This account intentionally stays outside the class so the delegate
        // approval screen always has one realistic pending request to test.
        student.SchoolClassId = null;
        student.UpdatedAt = DateTimeOffset.UtcNow;
        await userManager.UpdateAsync(student);
        await EnsureDevelopmentPasswordAsync(userManager, student);

        if (await userManager.IsInRoleAsync(student, nameof(UserRole.Eleve)))
        {
            await userManager.RemoveFromRoleAsync(student, nameof(UserRole.Eleve));
        }

        if (await userManager.IsInRoleAsync(student, nameof(UserRole.Delegue)))
        {
            await userManager.RemoveFromRoleAsync(student, nameof(UserRole.Delegue));
        }

        var existingPendingRequest = await dbContext.ClassMembershipRequests
            .SingleOrDefaultAsync(x => x.UserId == student.Id && x.Status == ClassMembershipRequestStatus.Pending);
        if (existingPendingRequest is null)
        {
            dbContext.ClassMembershipRequests.Add(new ClassMembershipRequest
            {
                SchoolClassId = schoolClassId,
                UserId = student.Id
            });
        }
        else
        {
            existingPendingRequest.SchoolClassId = schoolClassId;
        }

        await dbContext.SaveChangesAsync();
    }

    private static async Task EnsureDevelopmentPasswordAsync(
        UserManager<ApplicationUser> userManager,
        ApplicationUser user)
    {
        if (await userManager.HasPasswordAsync(user))
        {
            var removeResult = await userManager.RemovePasswordAsync(user);
            if (!removeResult.Succeeded)
            {
                throw new InvalidOperationException(
                    $"Impossible de remplacer le mot de passe dev pour {user.Email} : {string.Join(", ", removeResult.Errors.Select(x => x.Description))}");
            }
        }

        var result = await userManager.AddPasswordAsync(user, DelegatePassword);
        if (!result.Succeeded)
        {
            throw new InvalidOperationException(
                $"Impossible de synchroniser le mot de passe dev pour {user.Email} : {string.Join(", ", result.Errors.Select(x => x.Description))}");
        }
    }

    private static async Task EnsureRoleAsync(
        UserManager<ApplicationUser> userManager,
        ApplicationUser user,
        string role)
    {
        if (await userManager.IsInRoleAsync(user, role)) return;

        var result = await userManager.AddToRoleAsync(user, role);
        if (!result.Succeeded)
        {
            throw new InvalidOperationException(
                $"Impossible d'ajouter le rôle {role} : {string.Join(", ", result.Errors.Select(x => x.Description))}");
        }
    }

    private static async Task<Dictionary<string, Subject>> EnsureSubjectsAsync(
        StudyFlowDbContext dbContext,
        Guid schoolClassId,
        Guid userId)
    {
        var wantedSubjects = new[]
        {
            "Flutter",
            "API ASP.NET Core",
            "Base de données",
            "Anglais",
            "C",
            "Architecture web",
            "HTML/CSS/JS",
            "Administration Windows"
        };
        var subjects = await dbContext.Subjects
            .Where(x => x.SchoolClassId == schoolClassId)
            .ToListAsync();

        foreach (var name in wantedSubjects)
        {
            var existingSubject = subjects.SingleOrDefault(x => x.Name == name);
            if (existingSubject is not null)
            {
                // In development, a user may delete a seeded subject from the app.
                // The demo data still needs these subjects to create coherent courses.
                existingSubject.IsActive = true;
                continue;
            }

            var subject = new Subject
            {
                SchoolClassId = schoolClassId,
                Name = name,
                CreatedById = userId
            };
            dbContext.Subjects.Add(subject);
            subjects.Add(subject);
        }

        await dbContext.SaveChangesAsync();
        return subjects.Where(x => x.IsActive).ToDictionary(x => x.Name);
    }

    private static async Task<Dictionary<string, Teacher>> EnsureTeachersAsync(
        StudyFlowDbContext dbContext,
        ISensitiveDataProtector protector,
        Guid schoolClassId,
        Guid userId)
    {
        var wantedTeachers = new[]
        {
            ("Mme Dupont", "Référente Flutter"),
            ("M. Martin", "API et architecture"),
            ("Mme Bernard", "Base de données"),
            ("Mr Mahieux", "Langage C et algorithmique"),
            ("Mr Vaast", "Architecture web et conception"),
            ("Mr Debureau", "HTML, CSS et JavaScript"),
            ("Mr Alexandre", "Administration Windows")
        };
        var teachers = await dbContext.Teachers
            .Where(x => x.SchoolClassId == schoolClassId)
            .ToListAsync();

        foreach (var (displayName, information) in wantedTeachers)
        {
            var hash = protector.ComputeLookupHash(displayName, TeacherLookupPurpose);
            var existingTeacher = teachers.SingleOrDefault(x => x.SearchNameHash == hash);
            if (existingTeacher is not null)
            {
                // Same idea as subjects: keep the dev dataset self-healing after
                // manual tests in the app.
                existingTeacher.IsActive = true;
                continue;
            }

            var teacher = new Teacher
            {
                SchoolClassId = schoolClassId,
                EncryptedDisplayName = protector.Protect(displayName, TeacherDisplayPurpose),
                SearchNameHash = hash,
                EncryptedInformation = protector.Protect(information, TeacherInfoPurpose),
                CreatedById = userId
            };
            dbContext.Teachers.Add(teacher);
            teachers.Add(teacher);
        }

        await dbContext.SaveChangesAsync();

        var readableTeachers = new Dictionary<string, Teacher>();
        foreach (var teacher in teachers.Where(x => x.IsActive))
        {
            try
            {
                var displayName = protector.Unprotect(teacher.EncryptedDisplayName, TeacherDisplayPurpose);
                readableTeachers.TryAdd(displayName, teacher);
            }
            catch (CryptographicException)
            {
                // Development data can survive local key changes. If an older row cannot be
                // decrypted anymore, the seeder skips it and keeps the app startable.
            }
        }

        return readableTeachers;
    }

    private static async Task EnsureCoursesAsync(
        StudyFlowDbContext dbContext,
        ISensitiveDataProtector protector,
        Guid schoolClassId,
        Guid userId,
        IReadOnlyDictionary<string, Subject> subjects,
        IReadOnlyDictionary<string, Teacher> teachers)
    {
        var today = DateTime.Today;
        var monday = today.AddDays(-(int)today.DayOfWeek + (int)DayOfWeek.Monday);
        if (today.DayOfWeek == DayOfWeek.Sunday) monday = today.AddDays(-6);

        var courses = new[]
        {
            NewCourse("Flutter", "Mme Dupont", monday, "09:00", "11:00", "B204"),
            NewCourse("C", "Mr Mahieux", monday, "11:15", "12:45", "B204"),
            NewCourse("Architecture web", "Mr Vaast", monday.AddDays(1), "09:00", "10:30", "A102"),
            NewCourse("API ASP.NET Core", "M. Martin", monday.AddDays(1), "10:45", "12:15", "A102"),
            NewCourse("HTML/CSS/JS", "Mr Debureau", monday.AddDays(2), "09:00", "12:00", "C205"),
            NewCourse("Base de données", "Mme Bernard", monday.AddDays(2), "14:00", "16:00", "C301"),
            NewCourse("Administration Windows", "Mr Alexandre", monday.AddDays(3), "08:30", "10:30", "B112"),
            NewCourse("Anglais", null, monday.AddDays(4), "10:45", "12:15", "B112")
        };

        foreach (var course in courses)
        {
            var exists = await dbContext.Courses.AnyAsync(x =>
                x.SchoolClassId == schoolClassId
                && x.SubjectId == course.SubjectId
                && x.Day == course.Day
                && x.DeletedAt == null);
            if (!exists) dbContext.Courses.Add(course);
        }

        await dbContext.SaveChangesAsync();

        Course NewCourse(string subjectName, string? teacherName, DateTime day, string start, string end, string room)
        {
            return new Course
            {
                SchoolClassId = schoolClassId,
                SubjectId = subjects[subjectName].Id,
                TeacherId = teacherName is null ? null : teachers[teacherName].Id,
                Day = DateOnly.FromDateTime(day),
                EncryptedData = ProtectCourseData(protector, start, end, room),
                CreatedById = userId
            };
        }
    }

    private static async Task EnsureHomeworkAsync(
        StudyFlowDbContext dbContext,
        Guid schoolClassId,
        Guid userId)
    {
        var homework = new[]
        {
            NewHomework("Maquette Flutter à finaliser", "Préparer les écrans principaux pour la revue.", 2),
            NewHomework("Exercices C : pointeurs et tableaux", "Rendre les exercices sur les pointeurs, tableaux et fonctions.", 3),
            NewHomework("Schéma d'architecture web", "Dessiner le parcours client -> API -> base de données pour StudyFlow.", 4),
            NewHomework("Page HTML/CSS/JS responsive", "Créer une petite page responsive avec validation JavaScript simple.", 5),
            NewHomework("Compte-rendu API", "Expliquer auth, classes et confidentialité.", 6),
            NewHomework("Administration Windows", "Préparer une fiche sur utilisateurs, groupes, partages et droits NTFS.", 7)
        };

        foreach (var item in homework)
        {
            var exists = await dbContext.HomeworkItems.AnyAsync(x =>
                x.SchoolClassId == schoolClassId
                && x.Title == item.Title
                && x.DeletedAt == null);
            if (!exists) dbContext.HomeworkItems.Add(item);
        }

        await dbContext.SaveChangesAsync();

        Homework NewHomework(string title, string description, int daysFromToday) => new()
        {
            SchoolClassId = schoolClassId,
            Title = title,
            Description = description,
            Deadline = UtcDeadline(daysFromToday, hour: 18),
            CreatedById = userId
        };
    }

    private static async Task EnsureAnnouncementsAsync(
        StudyFlowDbContext dbContext,
        Guid schoolClassId,
        Guid userId)
    {
        var announcements = new[]
        {
            NewAnnouncement("Salle B204 confirmée pour les cours de C et Flutter lundi.", isPinned: true),
            NewAnnouncement("Mr Vaast a demandé de relire le schéma client/API/base avant architecture web.", isPinned: true),
            NewAnnouncement("Pensez à vérifier vos tâches HTML/CSS/JS avant la fin de semaine.", isPinned: false),
            NewAnnouncement("Administration Windows : préparez vos questions sur les droits NTFS.", isPinned: false)
        };

        foreach (var announcement in announcements)
        {
            var exists = await dbContext.ClassAnnouncements.AnyAsync(x =>
                x.SchoolClassId == schoolClassId
                && x.Content == announcement.Content
                && x.DeletedAt == null);
            if (!exists) dbContext.ClassAnnouncements.Add(announcement);
        }

        await dbContext.SaveChangesAsync();

        ClassAnnouncement NewAnnouncement(string content, bool isPinned) => new()
        {
            SchoolClassId = schoolClassId,
            AuthorId = userId,
            Content = content,
            IsPinned = isPinned
        };
    }

    private static async Task EnsurePersonalAgendaAsync(
        StudyFlowDbContext dbContext,
        ISensitiveDataProtector protector,
        Guid userId)
    {
        var tasks = new[]
        {
            NewTask("Relire le README", "Vérifier les commandes de lancement.", PersonalTaskCategory.School, 1, 17),
            NewTask("Réviser les pointeurs en C", "Refaire deux exercices avant le prochain cours de Mr Mahieux.", PersonalTaskCategory.School, 2, 17),
            NewTask("Finaliser la fiche Windows", "Résumer utilisateurs, groupes et permissions NTFS.", PersonalTaskCategory.School, 4, 16),
            NewTask("Envoyer une candidature", "Adapter le CV à l'offre choisie.", PersonalTaskCategory.Apprenticeship, 3, 12),
            NewTask("Relancer une entreprise web", "Envoyer un message de suivi avec lien GitHub et portfolio.", PersonalTaskCategory.Apprenticeship, 5, 10)
        };

        foreach (var task in tasks)
        {
            var exists = await dbContext.PersonalTasks.AnyAsync(x =>
                x.UserId == userId
                && x.Title == task.Title);
            if (!exists) dbContext.PersonalTasks.Add(task);
        }

        if (!await dbContext.PersonalEvents.AnyAsync(x => x.UserId == userId))
        {
            dbContext.PersonalEvents.Add(new PersonalEvent
            {
                UserId = userId,
                Day = DateOnly.FromDateTime(DateTime.Today),
                Category = PersonalEventCategory.Apprenticeship,
                EncryptedData = protector.Protect(
                    JsonSerializer.Serialize(
                        new PersonalEventProtectedData(
                            "Relance entreprise",
                            TimeOnly.Parse("16:00"),
                            TimeOnly.Parse("16:30"),
                            "Téléphone",
                            "Appeler après l'envoi du CV."),
                        JsonOptions),
                    PersonalEventDataPurpose),
                NotificationsEnabled = true
            });
        }

        await dbContext.SaveChangesAsync();

        PersonalTask NewTask(
            string title,
            string description,
            PersonalTaskCategory category,
            int daysFromToday,
            int hour) => new()
            {
                UserId = userId,
                Title = title,
                Description = description,
                Category = category,
                Deadline = UtcDeadline(daysFromToday, hour),
                NotificationsEnabled = true
            };
    }

    private static async Task EnsureApprenticeshipMessagesAsync(
        StudyFlowDbContext dbContext,
        ISensitiveDataProtector protector,
        Guid schoolClassId,
        Guid userId)
    {
        var messages = new[]
        {
            ("J'ai trouvé une offre intéressante en développement web junior, utile pour HTML/CSS/JS et architecture web.", "https://labonnealternance.apprentissage.beta.gouv.fr"),
            ("Pensez à chercher aussi avec les mots-clés administration systèmes Windows, support et technicien informatique.", "https://www.adzuna.fr"),
            ("Pour les candidatures dev, ajoutez un petit projet C ou JS sur GitHub : ça montre la progression.", "https://github.com")
        };

        var existingMessageCount = await dbContext.ApprenticeshipMessages
            .CountAsync(x => x.SchoolClassId == schoolClassId && x.DeletedAt == null);
        if (existingMessageCount >= messages.Length) return;

        foreach (var (content, link) in messages.Skip(existingMessageCount))
        {
            dbContext.ApprenticeshipMessages.Add(new ApprenticeshipMessage
            {
                SchoolClassId = schoolClassId,
                AuthorId = userId,
                EncryptedContent = protector.Protect(content, ApprenticeshipMessageContentPurpose),
                EncryptedLink = protector.Protect(link, ApprenticeshipMessageLinkPurpose)
            });
        }

        await dbContext.SaveChangesAsync();
    }

    private static void LogDevelopmentAccounts(ILogger logger, string classCode)
    {
        logger.LogInformation(
            """

            StudyFlow development seed ready.
            Class code: {ClassCode}

            Seeded accounts:
            - Delegate: gabriel@studyflow.dev / {Password}
            - Student:  garance@studyflow.dev / {Password}
            - Student:  liam@studyflow.dev / {Password}
            - Pending:  nina@studyflow.dev / {Password}

            """,
            classCode,
            DelegatePassword,
            DelegatePassword,
            DelegatePassword,
            DelegatePassword);
    }

    private static string ProtectCourseData(
        ISensitiveDataProtector protector,
        string startsAt,
        string endsAt,
        string room)
    {
        return protector.Protect(
            JsonSerializer.Serialize(
                new CourseProtectedData(TimeOnly.Parse(startsAt), TimeOnly.Parse(endsAt), room),
                JsonOptions),
            CourseDataPurpose);
    }

    private static DateTimeOffset UtcDeadline(int daysFromToday, int hour)
    {
        var date = DateTimeOffset.UtcNow.Date.AddDays(daysFromToday).AddHours(hour);
        return new DateTimeOffset(date, TimeSpan.Zero);
    }

    private sealed record CourseProtectedData(TimeOnly StartsAt, TimeOnly EndsAt, string Room);
    private sealed record PersonalEventProtectedData(
        string Title,
        TimeOnly StartsAt,
        TimeOnly EndsAt,
        string? Location,
        string? Notes);
}
