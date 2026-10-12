using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using StudyFlow.Domain.Apprenticeships;
using StudyFlow.Domain.Contributions;
using StudyFlow.Domain.Exams;
using StudyFlow.Domain.Groups;
using StudyFlow.Domain.Notes;
using StudyFlow.Domain.Support;
using StudyFlow.Domain.Notifications;
using StudyFlow.Domain.School;
using StudyFlow.Domain.Users;
using StudyFlow.Infrastructure.Identity;

namespace StudyFlow.Infrastructure.Persistence;

public sealed class StudyFlowDbContext(
    DbContextOptions<StudyFlowDbContext> options)
    : IdentityDbContext<ApplicationUser, IdentityRole<Guid>, Guid>(options)
{
    public DbSet<SchoolClass> SchoolClasses => Set<SchoolClass>();
    public DbSet<Subject> Subjects => Set<Subject>();
    public DbSet<Teacher> Teachers => Set<Teacher>();
    public DbSet<SubjectTeacher> SubjectTeachers => Set<SubjectTeacher>();
    public DbSet<Course> Courses => Set<Course>();
    public DbSet<Homework> HomeworkItems => Set<Homework>();
    public DbSet<HomeworkProgress> HomeworkProgressItems => Set<HomeworkProgress>();
    public DbSet<PersonalTask> PersonalTasks => Set<PersonalTask>();
    public DbSet<DailyNote> DailyNotes => Set<DailyNote>();
    public DbSet<Feedback> FeedbackItems => Set<Feedback>();
    public DbSet<PersonalEvent> PersonalEvents => Set<PersonalEvent>();
    public DbSet<ClassMembershipRequest> ClassMembershipRequests => Set<ClassMembershipRequest>();
    public DbSet<ApprenticeshipMessage> ApprenticeshipMessages => Set<ApprenticeshipMessage>();
    public DbSet<NotificationPreference> NotificationPreferences => Set<NotificationPreference>();
    public DbSet<NotificationDevice> NotificationDevices => Set<NotificationDevice>();
    public DbSet<NotificationDelivery> NotificationDeliveries => Set<NotificationDelivery>();
    public DbSet<UserAppSettings> UserAppSettings => Set<UserAppSettings>();
    public DbSet<ContributionRevision> ContributionRevisions => Set<ContributionRevision>();
    public DbSet<ClassAnnouncement> ClassAnnouncements => Set<ClassAnnouncement>();
    public DbSet<ApprenticeshipSearch> ApprenticeshipSearches => Set<ApprenticeshipSearch>();
    public DbSet<FavoriteOffer> FavoriteOffers => Set<FavoriteOffer>();
    public DbSet<ExamSession> ExamSessions => Set<ExamSession>();
    public DbSet<ExamSubject> ExamSubjects => Set<ExamSubject>();
    public DbSet<RevisionItem> RevisionItems => Set<RevisionItem>();
    public DbSet<RevisionItemCheck> RevisionItemChecks => Set<RevisionItemCheck>();
    public DbSet<RevisionResource> RevisionResources => Set<RevisionResource>();
    public DbSet<RevisionResourceFile> RevisionResourceFiles => Set<RevisionResourceFile>();
    public DbSet<StudyGroup> StudyGroups => Set<StudyGroup>();
    public DbSet<StudyGroupMember> StudyGroupMembers => Set<StudyGroupMember>();
    public DbSet<StudyGroupTask> StudyGroupTasks => Set<StudyGroupTask>();
    public DbSet<StudyGroupTaskAssignee> StudyGroupTaskAssignees => Set<StudyGroupTaskAssignee>();
    public DbSet<StudyGroupMessage> StudyGroupMessages => Set<StudyGroupMessage>();
    public DbSet<StudyGroupResource> StudyGroupResources => Set<StudyGroupResource>();
    public DbSet<StudyGroupResourceFile> StudyGroupResourceFiles => Set<StudyGroupResourceFile>();
    public DbSet<StudyGroupMeeting> StudyGroupMeetings => Set<StudyGroupMeeting>();
    public DbSet<StudyGroupMeetingVote> StudyGroupMeetingVotes => Set<StudyGroupMeetingVote>();
    public DbSet<UserAvailability> UserAvailabilities => Set<UserAvailability>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<PasswordResetToken> PasswordResetTokens => Set<PasswordResetToken>();
    public DbSet<EmailVerificationCode> EmailVerificationCodes => Set<EmailVerificationCode>();

    /// <summary>Membres actifs d'une classe qui ont le rôle Délégué, en une seule requête SQL.</summary>
    public IQueryable<ApplicationUser> ActiveDelegatesOfClass(Guid schoolClassId) =>
        Users.Where(user => user.SchoolClassId == schoolClassId
            && user.IsActive
            && UserRoles.Any(userRole => userRole.UserId == user.Id
                && Roles.Any(role => role.Id == userRole.RoleId && role.Name == nameof(UserRole.Delegue))));

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        ConfigureIdentity(modelBuilder);
        ConfigureSchool(modelBuilder);
        ConfigurePersonalData(modelBuilder);
        ConfigureUserPreferences(modelBuilder);
        ConfigureApprenticeships(modelBuilder);
        ConfigureContributions(modelBuilder);
        ConfigureExams(modelBuilder);
        ConfigureGroups(modelBuilder);
        ApplySnakeCaseColumnNames(modelBuilder);
    }

    private static void ConfigureIdentity(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<ApplicationUser>(entity =>
        {
            entity.ToTable("users");
            entity.Property(x => x.FirstName).HasMaxLength(80).IsRequired();
            entity.Property(x => x.LastName).HasMaxLength(80).IsRequired();
            entity.Property(x => x.Email).HasMaxLength(320);
            entity.HasOne(x => x.SchoolClass)
                .WithMany()
                .HasForeignKey(x => x.SchoolClassId)
                .OnDelete(DeleteBehavior.SetNull);
            entity.HasIndex(x => x.SchoolClassId);
        });

        modelBuilder.Entity<IdentityRole<Guid>>().ToTable("roles");
        modelBuilder.Entity<IdentityUserRole<Guid>>().ToTable("user_roles");
        modelBuilder.Entity<IdentityUserClaim<Guid>>().ToTable("user_claims");
        modelBuilder.Entity<IdentityUserLogin<Guid>>().ToTable("user_logins");
        modelBuilder.Entity<IdentityRoleClaim<Guid>>().ToTable("role_claims");
        modelBuilder.Entity<IdentityUserToken<Guid>>().ToTable("user_tokens");

        modelBuilder.Entity<RefreshToken>(entity =>
        {
            entity.ToTable("refresh_tokens");
            entity.Property(x => x.TokenHash).HasMaxLength(64).IsRequired();
            entity.Property(x => x.ReplacedByTokenHash).HasMaxLength(64);
            entity.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(x => x.TokenHash).IsUnique();
            entity.HasIndex(x => new { x.UserId, x.ExpiresAt });
        });

        modelBuilder.Entity<EmailVerificationCode>(entity =>
        {
            entity.ToTable("email_verification_codes");
            entity.Property(x => x.Email).HasMaxLength(320).IsRequired();
            entity.Property(x => x.CodeHash).HasMaxLength(64).IsRequired();
            entity.HasIndex(x => new { x.Email, x.ExpiresAt });
        });

        modelBuilder.Entity<PasswordResetToken>(entity =>
        {
            entity.ToTable("password_reset_tokens");
            entity.Property(x => x.TokenHash).HasMaxLength(64).IsRequired();
            entity.Property(x => x.RequestIpHash).HasMaxLength(64);
            entity.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(x => x.TokenHash).IsUnique();
            entity.HasIndex(x => new { x.UserId, x.ExpiresAt });
        });

        modelBuilder.Entity<IdentityRole<Guid>>().HasData(
            new IdentityRole<Guid>
            {
                Id = Guid.Parse("3f2a82b4-f75a-4bf7-b5e7-198d85d1ca34"),
                Name = "Eleve",
                NormalizedName = "ELEVE",
                ConcurrencyStamp = "studyflow-role-eleve"
            },
            new IdentityRole<Guid>
            {
                Id = Guid.Parse("f438558d-7e21-428b-bf4e-85de5ebfc96f"),
                Name = "Delegue",
                NormalizedName = "DELEGUE",
                ConcurrencyStamp = "studyflow-role-delegue"
            });
    }

    private static void ConfigureSchool(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<SchoolClass>(entity =>
        {
            entity.ToTable("school_classes", table => table.HasCheckConstraint(
                "ck_school_classes_school_year",
                "school_year ~ '^[0-9]{4}-[0-9]{4}$'"));
            entity.Property(x => x.Name).HasMaxLength(80).IsRequired();
            entity.Property(x => x.SchoolYear).HasMaxLength(9).IsRequired();
            entity.Property(x => x.AccessCodeHash).IsRequired();
            entity.Property(x => x.EncryptedAccessCode).IsRequired();
            entity.HasIndex(x => x.Name).IsUnique();
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.CreatedById).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<ClassMembershipRequest>(entity =>
        {
            entity.ToTable("class_membership_requests");
            entity.Property(x => x.Status).HasConversion<string>().HasMaxLength(20);
            entity.HasOne(x => x.SchoolClass).WithMany(x => x.MembershipRequests).HasForeignKey(x => x.SchoolClassId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.DecidedById).OnDelete(DeleteBehavior.Restrict);
            entity.HasIndex(x => new { x.UserId, x.Status });
            entity.HasIndex(x => x.UserId)
                .IsUnique()
                .HasFilter("status = 'Pending'");
            entity.HasIndex(x => new { x.SchoolClassId, x.Status, x.RequestedAt });
        });

        modelBuilder.Entity<Subject>(entity =>
        {
            entity.ToTable("subjects");
            entity.Property(x => x.Name).HasMaxLength(120).IsRequired();
            entity.HasOne(x => x.SchoolClass).WithMany(x => x.Subjects).HasForeignKey(x => x.SchoolClassId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.CreatedById).OnDelete(DeleteBehavior.Restrict);
            // Unicité limitée aux matières actives : une matière supprimée peut être recréée.
            entity.HasIndex(x => new { x.SchoolClassId, x.Name }).IsUnique().HasFilter("is_active");
        });

        modelBuilder.Entity<Teacher>(entity =>
        {
            entity.ToTable("teachers");
            entity.Property(x => x.EncryptedDisplayName).IsRequired();
            entity.Property(x => x.SearchNameHash).HasMaxLength(64).IsRequired();
            entity.Property(x => x.EncryptedInformation);
            entity.HasOne(x => x.SchoolClass).WithMany(x => x.Teachers).HasForeignKey(x => x.SchoolClassId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.CreatedById).OnDelete(DeleteBehavior.Restrict);
            entity.HasIndex(x => new { x.SchoolClassId, x.SearchNameHash }).IsUnique().HasFilter("is_active");
        });

        modelBuilder.Entity<SubjectTeacher>(entity =>
        {
            entity.ToTable("subject_teachers");
            entity.HasKey(x => new { x.SubjectId, x.TeacherId });
            entity.HasOne(x => x.Subject).WithMany(x => x.TeacherLinks).HasForeignKey(x => x.SubjectId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(x => x.Teacher).WithMany(x => x.SubjectLinks).HasForeignKey(x => x.TeacherId).OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(x => x.TeacherId);
        });

        modelBuilder.Entity<Course>(entity =>
        {
            entity.ToTable("courses");
            entity.Property(x => x.EncryptedData).IsRequired();
            entity.Property(x => x.Version).IsConcurrencyToken();
            entity.HasOne(x => x.SchoolClass).WithMany(x => x.Courses).HasForeignKey(x => x.SchoolClassId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(x => x.Subject).WithMany(x => x.Courses).HasForeignKey(x => x.SubjectId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(x => x.Teacher).WithMany(x => x.Courses).HasForeignKey(x => x.TeacherId).OnDelete(DeleteBehavior.SetNull);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.CreatedById).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.UpdatedById).OnDelete(DeleteBehavior.Restrict);
            entity.HasIndex(x => new { x.SchoolClassId, x.Day });
            entity.HasIndex(x => x.SeriesId);
            entity.HasQueryFilter(x => x.DeletedAt == null);
        });

        modelBuilder.Entity<Homework>(entity =>
        {
            entity.ToTable("homework");
            entity.Property(x => x.Title).HasMaxLength(160).IsRequired();
            entity.HasOne(x => x.SchoolClass).WithMany(x => x.Homeworks).HasForeignKey(x => x.SchoolClassId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(x => x.Course).WithMany(x => x.Homeworks).HasForeignKey(x => x.CourseId).OnDelete(DeleteBehavior.SetNull);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.CreatedById).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.UpdatedById).OnDelete(DeleteBehavior.Restrict);
            entity.HasIndex(x => new { x.SchoolClassId, x.Deadline });
            entity.HasQueryFilter(x => x.DeletedAt == null);
        });

        modelBuilder.Entity<HomeworkProgress>(entity =>
        {
            entity.ToTable("homework_progress");
            entity.HasOne(x => x.Homework).WithMany(x => x.ProgressItems).HasForeignKey(x => x.HomeworkId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(x => new { x.HomeworkId, x.UserId }).IsUnique();
            entity.HasQueryFilter(x => x.Homework.DeletedAt == null);
        });

        modelBuilder.Entity<ClassAnnouncement>(entity =>
        {
            entity.ToTable("class_announcements");
            entity.Property(x => x.Content).HasMaxLength(2000).IsRequired();
            entity.HasOne(x => x.SchoolClass).WithMany(x => x.Announcements).HasForeignKey(x => x.SchoolClassId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.AuthorId).OnDelete(DeleteBehavior.Restrict);
            entity.HasIndex(x => new { x.SchoolClassId, x.IsPinned });
            entity.HasQueryFilter(x => x.DeletedAt == null);
        });

        modelBuilder.Entity<ApprenticeshipMessage>(entity =>
        {
            entity.ToTable("apprenticeship_messages");
            entity.Property(x => x.EncryptedContent).IsRequired();
            entity.HasOne(x => x.SchoolClass).WithMany(x => x.ApprenticeshipMessages).HasForeignKey(x => x.SchoolClassId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.AuthorId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.DeletedById).OnDelete(DeleteBehavior.Restrict);
            entity.HasIndex(x => new { x.SchoolClassId, x.CreatedAt });
            entity.HasQueryFilter(x => x.DeletedAt == null);
        });
    }

    private static void ConfigurePersonalData(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Feedback>(entity =>
        {
            entity.ToTable("feedback");
            entity.Property(x => x.Kind).HasConversion<string>().HasMaxLength(10);
            entity.Property(x => x.Message).HasMaxLength(4000).IsRequired();
            entity.Property(x => x.AppVersion).HasMaxLength(30);
            entity.Property(x => x.Platform).HasMaxLength(20);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(x => new { x.UserId, x.CreatedAt });
        });

        modelBuilder.Entity<DailyNote>(entity =>
        {
            entity.ToTable("daily_notes");
            entity.Property(x => x.EncryptedText).IsRequired();
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(x => new { x.UserId, x.Day }).IsUnique();
        });

        modelBuilder.Entity<PersonalTask>(entity =>
        {
            entity.ToTable("personal_tasks");
            entity.Property(x => x.Title).HasMaxLength(160).IsRequired();
            entity.Property(x => x.Category).HasConversion<string>().HasMaxLength(20);
            entity.HasOne(x => x.Course).WithMany().HasForeignKey(x => x.CourseId).OnDelete(DeleteBehavior.SetNull);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(x => new { x.UserId, x.Deadline });
        });

        modelBuilder.Entity<PersonalEvent>(entity =>
        {
            entity.ToTable("personal_events");
            entity.Property(x => x.EncryptedData).IsRequired();
            entity.Property(x => x.Category).HasConversion<string>().HasMaxLength(20);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(x => new { x.UserId, x.Day });
        });

        modelBuilder.Entity<NotificationDevice>(entity =>
        {
            entity.ToTable("notification_devices");
            entity.Property(x => x.TokenHash).HasMaxLength(64).IsRequired();
            entity.Property(x => x.EncryptedToken).IsRequired();
            entity.Property(x => x.Platform).HasConversion<string>().HasMaxLength(20);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(x => x.TokenHash).IsUnique();
        });

        modelBuilder.Entity<NotificationDelivery>(entity =>
        {
            entity.ToTable("notification_deliveries");
            entity.Property(x => x.Type).HasMaxLength(40).IsRequired();
            entity.Property(x => x.Status).HasConversion<string>().HasMaxLength(20);
            entity.Property(x => x.ErrorMessage).HasMaxLength(1000);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(x => new { x.UserId, x.Type, x.RelatedEntityId, x.ScheduledAt }).IsUnique();
        });
    }

    private static void ConfigureUserPreferences(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<NotificationPreference>(entity =>
        {
            entity.ToTable("notification_preferences", table => table.HasCheckConstraint(
                "ck_notification_preferences_course_reminder_minutes",
                "course_reminder_minutes IN (0, 5, 10, 15, 30, 60)"));
            entity.HasOne<ApplicationUser>().WithOne().HasForeignKey<NotificationPreference>(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(x => x.UserId).IsUnique();
            entity.Property(x => x.QuietHoursStart).HasDefaultValue(new TimeOnly(22, 0));
            entity.Property(x => x.QuietHoursEnd).HasDefaultValue(new TimeOnly(7, 0));
        });

        modelBuilder.Entity<UserAppSettings>(entity =>
        {
            entity.ToTable("user_app_settings");
            entity.Property(x => x.Theme).HasConversion<string>().HasMaxLength(20);
            entity.Property(x => x.ProfessionalMode).HasConversion<string>().HasMaxLength(30);
            entity.Property(x => x.CompanyName).HasMaxLength(160);
            entity.HasOne<ApplicationUser>().WithOne().HasForeignKey<UserAppSettings>(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(x => x.UserId).IsUnique();
        });
    }

    private static void ConfigureApprenticeships(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<ApprenticeshipSearch>(entity =>
        {
            entity.ToTable("apprenticeship_searches");
            entity.Property(x => x.Name).HasMaxLength(100).IsRequired();
            entity.Property(x => x.Keywords).HasMaxLength(200).IsRequired();
            entity.Property(x => x.Location).HasMaxLength(200);
            entity.Property(x => x.Latitude).HasPrecision(9, 6);
            entity.Property(x => x.Longitude).HasPrecision(9, 6);
            entity.Property(x => x.FiltersJson).HasColumnType("jsonb");
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<FavoriteOffer>(entity =>
        {
            entity.ToTable("favorite_offers");
            entity.Property(x => x.Source).HasMaxLength(80).IsRequired();
            entity.Property(x => x.ExternalOfferId).HasMaxLength(200).IsRequired();
            entity.Property(x => x.Title).HasMaxLength(250).IsRequired();
            entity.Property(x => x.Company).HasMaxLength(200);
            entity.Property(x => x.Location).HasMaxLength(200);
            entity.Property(x => x.Url).IsRequired();
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(x => new { x.UserId, x.Source, x.ExternalOfferId }).IsUnique();
        });
    }

    private static void ConfigureContributions(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<ContributionRevision>(entity =>
        {
            entity.ToTable("contribution_revisions");
            entity.Property(x => x.EntityType).HasConversion<string>().HasMaxLength(30);
            entity.Property(x => x.Action).HasConversion<string>().HasMaxLength(20);
            entity.Property(x => x.EncryptedSnapshot).IsRequired();
            entity.HasOne<SchoolClass>().WithMany().HasForeignKey(x => x.SchoolClassId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.AuthorId).OnDelete(DeleteBehavior.Restrict);
            entity.HasIndex(x => new { x.EntityType, x.EntityId, x.CreatedAt });
        });
    }

    private static void ConfigureExams(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<ExamSession>(entity =>
        {
            entity.ToTable("exam_sessions");
            entity.Property(x => x.Title).HasMaxLength(80).IsRequired();
            entity.Ignore(x => x.OpensOn);
            entity.HasOne(x => x.SchoolClass).WithMany().HasForeignKey(x => x.SchoolClassId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.CreatedById).OnDelete(DeleteBehavior.Restrict);
            entity.HasIndex(x => new { x.SchoolClassId, x.StartsOn });
        });

        modelBuilder.Entity<ExamSubject>(entity =>
        {
            entity.ToTable("exam_subjects");
            entity.Property(x => x.Details).HasMaxLength(200);
            entity.HasOne(x => x.Session).WithMany(x => x.Subjects).HasForeignKey(x => x.ExamSessionId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(x => x.Subject).WithMany().HasForeignKey(x => x.SubjectId).OnDelete(DeleteBehavior.Restrict);
            entity.HasIndex(x => new { x.ExamSessionId, x.SubjectId }).IsUnique();
        });

        modelBuilder.Entity<RevisionItem>(entity =>
        {
            entity.ToTable("revision_items");
            entity.Property(x => x.Text).HasMaxLength(500).IsRequired();
            entity.HasOne(x => x.ExamSubject).WithMany(x => x.Items).HasForeignKey(x => x.ExamSubjectId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.AuthorId).OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(x => new { x.ExamSubjectId, x.CreatedAt });
        });

        modelBuilder.Entity<RevisionItemCheck>(entity =>
        {
            entity.ToTable("revision_item_checks");
            entity.HasKey(x => new { x.RevisionItemId, x.UserId });
            entity.HasOne(x => x.Item).WithMany(x => x.Checks).HasForeignKey(x => x.RevisionItemId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(x => x.UserId);
        });

        modelBuilder.Entity<RevisionResource>(entity =>
        {
            entity.ToTable("revision_resources");
            entity.Property(x => x.Title).HasMaxLength(120).IsRequired();
            entity.Property(x => x.Kind).HasConversion<string>().HasMaxLength(10);
            entity.Property(x => x.Url).HasMaxLength(2000);
            entity.Property(x => x.FileName).HasMaxLength(120);
            entity.Property(x => x.FileType).HasMaxLength(10);
            entity.Property(x => x.ContentType).HasMaxLength(80);
            entity.HasOne(x => x.ExamSubject).WithMany(x => x.Resources).HasForeignKey(x => x.ExamSubjectId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.AuthorId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(x => x.File).WithOne().HasForeignKey<RevisionResourceFile>(x => x.RevisionResourceId).OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(x => new { x.ExamSubjectId, x.CreatedAt });
        });

        modelBuilder.Entity<RevisionResourceFile>(entity =>
        {
            entity.ToTable("revision_resource_files");
            entity.HasKey(x => x.RevisionResourceId);
            entity.Property(x => x.Content).IsRequired();
        });
    }

    private static void ConfigureGroups(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<StudyGroup>(entity =>
        {
            entity.ToTable("study_groups");
            entity.Property(x => x.Name).HasMaxLength(60).IsRequired();
            entity.Ignore(x => x.EffectiveDueAt);
            entity.HasOne(x => x.SchoolClass).WithMany().HasForeignKey(x => x.SchoolClassId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(x => x.Subject).WithMany().HasForeignKey(x => x.SubjectId).OnDelete(DeleteBehavior.SetNull);
            entity.HasOne(x => x.Homework).WithMany().HasForeignKey(x => x.HomeworkId).OnDelete(DeleteBehavior.SetNull);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.CreatedById).OnDelete(DeleteBehavior.SetNull);
            entity.HasIndex(x => new { x.SchoolClassId, x.HomeworkId });
        });

        modelBuilder.Entity<StudyGroupMember>(entity =>
        {
            entity.ToTable("study_group_members");
            entity.HasKey(x => new { x.StudyGroupId, x.UserId });
            entity.Property(x => x.Role).HasConversion<string>().HasMaxLength(12);
            entity.Property(x => x.Status).HasConversion<string>().HasMaxLength(10);
            entity.Property(x => x.RoleLabel).HasMaxLength(40);
            entity.HasOne(x => x.Group).WithMany(x => x.Members).HasForeignKey(x => x.StudyGroupId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(x => x.UserId);
        });

        modelBuilder.Entity<StudyGroupTask>(entity =>
        {
            entity.ToTable("study_group_tasks");
            entity.Property(x => x.EncryptedTitle).IsRequired();
            entity.Property(x => x.Status).HasConversion<string>().HasMaxLength(10);
            entity.HasOne(x => x.Group).WithMany(x => x.Tasks).HasForeignKey(x => x.StudyGroupId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.CreatedById).OnDelete(DeleteBehavior.SetNull);
            entity.HasIndex(x => new { x.StudyGroupId, x.CreatedAt });
        });

        modelBuilder.Entity<StudyGroupTaskAssignee>(entity =>
        {
            entity.ToTable("study_group_task_assignees");
            entity.HasKey(x => new { x.StudyGroupTaskId, x.UserId });
            entity.HasOne(x => x.Task).WithMany(x => x.Assignees).HasForeignKey(x => x.StudyGroupTaskId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(x => x.UserId);
        });

        modelBuilder.Entity<StudyGroupMessage>(entity =>
        {
            entity.ToTable("study_group_messages");
            entity.Property(x => x.EncryptedText).IsRequired();
            entity.HasOne(x => x.Group).WithMany().HasForeignKey(x => x.StudyGroupId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.AuthorId).OnDelete(DeleteBehavior.SetNull);
            entity.HasIndex(x => new { x.StudyGroupId, x.CreatedAt });
        });

        modelBuilder.Entity<StudyGroupResource>(entity =>
        {
            entity.ToTable("study_group_resources");
            entity.Property(x => x.Kind).HasConversion<string>().HasMaxLength(10);
            entity.Property(x => x.EncryptedTitle).IsRequired();
            entity.Property(x => x.FileName).HasMaxLength(120);
            entity.Property(x => x.FileType).HasMaxLength(10);
            entity.Property(x => x.ContentType).HasMaxLength(80);
            entity.HasOne(x => x.Group).WithMany().HasForeignKey(x => x.StudyGroupId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.AuthorId).OnDelete(DeleteBehavior.SetNull);
            entity.HasOne(x => x.File).WithOne().HasForeignKey<StudyGroupResourceFile>(x => x.StudyGroupResourceId).OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(x => new { x.StudyGroupId, x.CreatedAt });
        });

        modelBuilder.Entity<StudyGroupResourceFile>(entity =>
        {
            entity.ToTable("study_group_resource_files");
            entity.HasKey(x => x.StudyGroupResourceId);
            entity.Property(x => x.EncryptedContent).IsRequired();
        });

        modelBuilder.Entity<StudyGroupMeeting>(entity =>
        {
            entity.ToTable("study_group_meetings");
            entity.Property(x => x.Mode).HasConversion<string>().HasMaxLength(10);
            entity.Property(x => x.Status).HasConversion<string>().HasMaxLength(10);
            entity.HasOne(x => x.Group).WithMany().HasForeignKey(x => x.StudyGroupId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.ProposedById).OnDelete(DeleteBehavior.SetNull);
            entity.HasIndex(x => new { x.StudyGroupId, x.StartsAt });
        });

        modelBuilder.Entity<StudyGroupMeetingVote>(entity =>
        {
            entity.ToTable("study_group_meeting_votes");
            entity.HasKey(x => new { x.StudyGroupMeetingId, x.UserId });
            entity.HasOne(x => x.Meeting).WithMany(x => x.Votes).HasForeignKey(x => x.StudyGroupMeetingId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<UserAvailability>(entity =>
        {
            entity.ToTable("user_availabilities");
            entity.HasKey(x => x.UserId);
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        });
    }

    private static void ApplySnakeCaseColumnNames(ModelBuilder modelBuilder)
    {
        foreach (var entityType in modelBuilder.Model.GetEntityTypes())
        {
            foreach (var property in entityType.GetProperties())
            {
                property.SetColumnName(ToSnakeCase(property.Name));
            }
        }
    }

    private static string ToSnakeCase(string value)
    {
        var characters = new List<char>(value.Length + 8);
        for (var index = 0; index < value.Length; index++)
        {
            var character = value[index];
            if (char.IsUpper(character) && index > 0)
            {
                characters.Add('_');
            }

            characters.Add(char.ToLowerInvariant(character));
        }

        return new string([.. characters]);
    }
}
