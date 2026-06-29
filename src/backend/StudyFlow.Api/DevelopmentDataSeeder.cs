using System.Text.Json;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using StudyFlow.Application.Security;
using StudyFlow.Domain.School;
using StudyFlow.Domain.Users;
using StudyFlow.Infrastructure.Identity;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Api;

public static class DevelopmentDataSeeder
{
    private const string DelegateEmail = "gabriel@studyflow.dev";
    private const string DelegatePassword = "Password1234";
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
        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var classCodeService = scope.ServiceProvider.GetRequiredService<IClassCodeService>();
        var protector = scope.ServiceProvider.GetRequiredService<ISensitiveDataProtector>();

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

        var subjects = await EnsureSubjectsAsync(dbContext, schoolClass.Id, delegateUser.Id);
        var teachers = await EnsureTeachersAsync(dbContext, protector, schoolClass.Id, delegateUser.Id);
        await EnsureCoursesAsync(dbContext, protector, schoolClass.Id, delegateUser.Id, subjects, teachers);
        await EnsureHomeworkAsync(dbContext, schoolClass.Id, delegateUser.Id);
        await EnsureAnnouncementsAsync(dbContext, schoolClass.Id, delegateUser.Id);
        await EnsurePersonalAgendaAsync(dbContext, protector, delegateUser.Id);
        await EnsureApprenticeshipMessagesAsync(dbContext, protector, schoolClass.Id, delegateUser.Id);
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
        var wantedSubjects = new[] { "Flutter", "API ASP.NET Core", "Base de données", "Anglais" };
        var subjects = await dbContext.Subjects
            .Where(x => x.SchoolClassId == schoolClassId)
            .ToListAsync();

        foreach (var name in wantedSubjects)
        {
            if (subjects.Any(x => x.Name == name)) continue;
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
            ("Mme Bernard", "Base de données")
        };
        var teachers = await dbContext.Teachers
            .Where(x => x.SchoolClassId == schoolClassId)
            .ToListAsync();

        foreach (var (displayName, information) in wantedTeachers)
        {
            var hash = protector.ComputeLookupHash(displayName, TeacherLookupPurpose);
            if (teachers.Any(x => x.SearchNameHash == hash)) continue;

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
        return teachers
            .Where(x => x.IsActive)
            .ToDictionary(x => protector.Unprotect(x.EncryptedDisplayName, TeacherDisplayPurpose));
    }

    private static async Task EnsureCoursesAsync(
        StudyFlowDbContext dbContext,
        ISensitiveDataProtector protector,
        Guid schoolClassId,
        Guid userId,
        IReadOnlyDictionary<string, Subject> subjects,
        IReadOnlyDictionary<string, Teacher> teachers)
    {
        if (await dbContext.Courses.AnyAsync(x => x.SchoolClassId == schoolClassId)) return;

        var today = DateTime.Today;
        var monday = today.AddDays(-(int)today.DayOfWeek + (int)DayOfWeek.Monday);
        if (today.DayOfWeek == DayOfWeek.Sunday) monday = today.AddDays(-6);

        dbContext.Courses.AddRange(
            NewCourse("Flutter", "Mme Dupont", monday, "09:00", "11:00", "B204"),
            NewCourse("API ASP.NET Core", "M. Martin", monday.AddDays(1), "10:15", "12:15", "A102"),
            NewCourse("Base de données", "Mme Bernard", monday.AddDays(2), "14:00", "16:00", "C301"),
            NewCourse("Anglais", null, monday.AddDays(3), "08:30", "10:00", "B112"));

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
        if (await dbContext.HomeworkItems.AnyAsync(x => x.SchoolClassId == schoolClassId)) return;

        dbContext.HomeworkItems.AddRange(
            new Homework
            {
                SchoolClassId = schoolClassId,
                Title = "Maquette Flutter à finaliser",
                Description = "Préparer les écrans principaux pour la revue.",
                Deadline = UtcDeadline(daysFromToday: 2, hour: 18),
                CreatedById = userId
            },
            new Homework
            {
                SchoolClassId = schoolClassId,
                Title = "Compte-rendu API",
                Description = "Expliquer auth, classes et confidentialité.",
                Deadline = UtcDeadline(daysFromToday: 5, hour: 18),
                CreatedById = userId
            });

        await dbContext.SaveChangesAsync();
    }

    private static async Task EnsureAnnouncementsAsync(
        StudyFlowDbContext dbContext,
        Guid schoolClassId,
        Guid userId)
    {
        if (await dbContext.ClassAnnouncements.AnyAsync(x => x.SchoolClassId == schoolClassId)) return;

        dbContext.ClassAnnouncements.AddRange(
            new ClassAnnouncement
            {
                SchoolClassId = schoolClassId,
                AuthorId = userId,
                Content = "Salle B204 confirmée pour le cours Flutter de lundi.",
                IsPinned = true
            },
            new ClassAnnouncement
            {
                SchoolClassId = schoolClassId,
                AuthorId = userId,
                Content = "Pensez à vérifier vos tâches avant la fin de semaine.",
                IsPinned = false
            });

        await dbContext.SaveChangesAsync();
    }

    private static async Task EnsurePersonalAgendaAsync(
        StudyFlowDbContext dbContext,
        ISensitiveDataProtector protector,
        Guid userId)
    {
        if (!await dbContext.PersonalTasks.AnyAsync(x => x.UserId == userId))
        {
            dbContext.PersonalTasks.AddRange(
                new PersonalTask
                {
                    UserId = userId,
                    Title = "Relire le README",
                    Description = "Vérifier les commandes de lancement.",
                    Category = PersonalTaskCategory.School,
                    Deadline = UtcDeadline(daysFromToday: 1, hour: 17),
                    NotificationsEnabled = true
                },
                new PersonalTask
                {
                    UserId = userId,
                    Title = "Envoyer une candidature",
                    Description = "Adapter le CV à l'offre choisie.",
                    Category = PersonalTaskCategory.Apprenticeship,
                    Deadline = UtcDeadline(daysFromToday: 3, hour: 12),
                    NotificationsEnabled = true
                });
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
    }

    private static async Task EnsureApprenticeshipMessagesAsync(
        StudyFlowDbContext dbContext,
        ISensitiveDataProtector protector,
        Guid schoolClassId,
        Guid userId)
    {
        if (await dbContext.ApprenticeshipMessages.AnyAsync(x => x.SchoolClassId == schoolClassId)) return;

        dbContext.ApprenticeshipMessages.Add(new ApprenticeshipMessage
        {
            SchoolClassId = schoolClassId,
            AuthorId = userId,
            EncryptedContent = protector.Protect(
                "J'ai trouvé une offre intéressante en développement web junior.",
                ApprenticeshipMessageContentPurpose),
            EncryptedLink = protector.Protect(
                "https://labonnealternance.apprentissage.beta.gouv.fr",
                ApprenticeshipMessageLinkPurpose)
        });

        await dbContext.SaveChangesAsync();
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
