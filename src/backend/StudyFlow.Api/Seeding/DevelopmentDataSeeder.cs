using System.Text.Json;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using StudyFlow.Application.Security;
using StudyFlow.Application.Time;
using StudyFlow.Domain.School;
using StudyFlow.Domain.Users;
using StudyFlow.Infrastructure.Identity;
using StudyFlow.Infrastructure.Persistence;

namespace StudyFlow.Api.Seeding;

/// <summary>
/// Données de développement : une vraie classe de BTS SIO en alternance, avec ses semaines
/// école / entreprise, ses devoirs, ses partiels, ses groupes de travail et la vie perso de
/// Gabriel (le délégué). Tout est daté par rapport à aujourd'hui, en heure de Paris.
/// <para>
/// Les comptes sont recréés à chaque démarrage (mots de passe remis à zéro) ; le contenu
/// n'est créé que dans une base vide. Pour repartir de zéro : <c>make dev-reset</c>.
/// </para>
/// </summary>
public static class DevelopmentDataSeeder
{
    public const string Password = "Password1234!";
    public const string ClassName = "BTS SIO 1";

    public static async Task SeedDevelopmentDataAsync(this IServiceProvider services)
    {
        using var scope = services.CreateScope();
        var provider = scope.ServiceProvider;
        var dbContext = provider.GetRequiredService<StudyFlowDbContext>();
        var configuration = provider.GetRequiredService<IConfiguration>();
        var logger = provider.GetRequiredService<ILoggerFactory>().CreateLogger(nameof(DevelopmentDataSeeder));

        if (configuration.GetValue<bool>("DevelopmentSeed:ResetOnStartup"))
        {
            // Garde-fou : un serveur lancé par erreur en Development ne doit jamais effacer une vraie base.
            var databaseHost = new NpgsqlConnectionStringBuilder(dbContext.Database.GetConnectionString()).Host;
            if (IsLocalDatabaseHost(databaseHost) || configuration.GetValue<bool>("DevelopmentSeed:AllowRemoteReset"))
            {
                logger.LogWarning("DevelopmentSeed:ResetOnStartup=true : la base de développement est effacée puis recréée.");
                await dbContext.Database.EnsureDeletedAsync();
            }
            else
            {
                logger.LogError(
                    "DevelopmentSeed:ResetOnStartup ignoré : la base {Host} n'est pas locale. "
                    + "Mettre DevelopmentSeed:AllowRemoteReset=true seulement pour une base jetable.",
                    databaseHost);
            }
        }

        await dbContext.Database.MigrateAsync();

        var seed = new DevelopmentSeed(
            dbContext,
            provider.GetRequiredService<UserManager<ApplicationUser>>(),
            provider.GetRequiredService<ISensitiveDataProtector>(),
            provider.GetRequiredService<IClassCodeService>(),
            provider.GetRequiredService<ISchoolClock>(),
            logger);
        await seed.RunAsync();
    }

    private static bool IsLocalDatabaseHost(string? host) =>
        host is not null
        && host.Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries)
            .All(x => x is "localhost" or "127.0.0.1" or "::1");
}

/// <summary>Une exécution du seed : services, classe et comptes partagés par les étapes.</summary>
internal sealed partial class DevelopmentSeed(
    StudyFlowDbContext db,
    UserManager<ApplicationUser> userManager,
    ISensitiveDataProtector protector,
    IClassCodeService classCodes,
    ISchoolClock clock,
    ILogger logger)
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    /// <summary>Les élèves de la classe, par prénom. Gabriel est le délégué.</summary>
    private static readonly (string Key, string Email, string FirstName, string LastName)[] Students =
    [
        ("gabriel", "gabriel@studyflow.dev", "Gabriel", "Glaize"),
        ("garance", "garance@studyflow.dev", "Garance", "Moreau"),
        ("liam", "liam@studyflow.dev", "Liam", "Petit"),
        ("ines", "ines@studyflow.dev", "Inès", "Benali"),
        ("yanis", "yanis@studyflow.dev", "Yanis", "Kaci"),
        ("chloe", "chloe@studyflow.dev", "Chloé", "Durand"),
        ("hugo", "hugo@studyflow.dev", "Hugo", "Lefèvre"),
        ("sarah", "sarah@studyflow.dev", "Sarah", "Fontaine")
    ];

    private const string PendingEmail = "nina@studyflow.dev";

    private readonly Dictionary<string, ApplicationUser> _users = [];
    private SchoolClass _class = null!;

    private ApplicationUser Gabriel => _users["gabriel"];

    private DateOnly Today => clock.Today;

    public async Task RunAsync()
    {
        foreach (var (key, email, firstName, lastName) in Students)
        {
            _users[key] = await EnsureUserAsync(email, firstName, lastName);
        }

        await EnsureClassAsync();
        foreach (var user in _users.Values)
        {
            await EnsureRoleAsync(user, nameof(UserRole.Eleve));
        }

        await EnsureRoleAsync(Gabriel, nameof(UserRole.Delegue));
        await EnsurePendingRequestAsync();

        // Le contenu n'est créé qu'une fois : une base déjà remplie garde ce qu'on y a fait.
        if (await db.Courses.IgnoreQueryFilters().AnyAsync(x => x.SchoolClassId == _class.Id))
        {
            logger.LogInformation("Seed : contenu déjà présent, seuls les comptes ont été vérifiés.");
        }
        else
        {
            var school = await SeedSchoolAsync();
            await SeedExamsAsync(school);
            await SeedGroupsAsync(school);
            await SeedPersonalAsync(school);
            logger.LogInformation("Seed : classe complète créée ({Courses} cours).", school.Courses.Count);
        }

        LogAccounts(classCodes.Reveal(_class.EncryptedAccessCode));
    }

    private async Task<ApplicationUser> EnsureUserAsync(string email, string firstName, string lastName)
    {
        var user = await userManager.FindByEmailAsync(email);
        if (user is null)
        {
            user = new ApplicationUser
            {
                Id = Guid.NewGuid(),
                UserName = email,
                Email = email,
                EmailConfirmed = true,
                FirstName = firstName,
                LastName = lastName
            };
            Check(await userManager.CreateAsync(user, DevelopmentDataSeeder.Password), $"créer {email}");
            return user;
        }

        // Un mot de passe changé pendant les tests revient à la valeur connue. On ne touche à
        // rien sinon : changer le mot de passe déconnecterait l'app à chaque redémarrage.
        if (!await userManager.CheckPasswordAsync(user, DevelopmentDataSeeder.Password))
        {
            if (await userManager.HasPasswordAsync(user)) Check(await userManager.RemovePasswordAsync(user), $"retirer le mot de passe de {email}");
            Check(await userManager.AddPasswordAsync(user, DevelopmentDataSeeder.Password), $"remettre le mot de passe de {email}");
        }

        return user;
    }

    private async Task EnsureClassAsync()
    {
        var schoolClass = await db.SchoolClasses.SingleOrDefaultAsync(x => x.Name == DevelopmentDataSeeder.ClassName);
        if (schoolClass is null)
        {
            var code = classCodes.Generate();
            schoolClass = new SchoolClass
            {
                Name = DevelopmentDataSeeder.ClassName,
                SchoolYear = "2026-2027",
                AccessCodeHash = code.Hash,
                EncryptedAccessCode = code.Ciphertext,
                AccessCodeUpdatedAt = DateTimeOffset.UtcNow,
                CreatedById = Gabriel.Id
            };
            db.SchoolClasses.Add(schoolClass);
            await db.SaveChangesAsync();
        }

        _class = schoolClass;
        foreach (var user in _users.Values.Where(x => x.SchoolClassId != schoolClass.Id))
        {
            user.SchoolClassId = schoolClass.Id;
            Check(await userManager.UpdateAsync(user), $"rattacher {user.Email}");
        }
    }

    /// <summary>Nina a demandé à rejoindre la classe : l'écran d'approbation du délégué a toujours une demande.</summary>
    private async Task EnsurePendingRequestAsync()
    {
        var nina = await EnsureUserAsync(PendingEmail, "Nina", "Lemoine");
        if (nina.SchoolClassId is not null)
        {
            nina.SchoolClassId = null;
            Check(await userManager.UpdateAsync(nina), "sortir Nina de la classe");
        }

        foreach (var role in new[] { nameof(UserRole.Eleve), nameof(UserRole.Delegue) })
        {
            if (await userManager.IsInRoleAsync(nina, role)) await userManager.RemoveFromRoleAsync(nina, role);
        }

        var pending = await db.ClassMembershipRequests
            .AnyAsync(x => x.UserId == nina.Id && x.Status == ClassMembershipRequestStatus.Pending);
        if (!pending)
        {
            db.ClassMembershipRequests.Add(new ClassMembershipRequest { SchoolClassId = _class.Id, UserId = nina.Id });
            await db.SaveChangesAsync();
        }
    }

    private async Task EnsureRoleAsync(ApplicationUser user, string role)
    {
        if (!await userManager.IsInRoleAsync(user, role)) Check(await userManager.AddToRoleAsync(user, role), $"rôle {role}");
    }

    private static void Check(IdentityResult result, string action)
    {
        if (!result.Succeeded)
        {
            throw new InvalidOperationException(
                $"Seed : impossible de {action} : {string.Join(", ", result.Errors.Select(x => x.Description))}");
        }
    }

    /// <summary>Instant UTC d'un jour et d'une heure de Paris (PostgreSQL n'accepte que l'UTC).</summary>
    private DateTimeOffset At(DateOnly day, int hour, int minute = 0) =>
        clock.ToSchoolTime(day, new TimeOnly(hour, minute)).ToUniversalTime();

    private string ProtectJson<T>(T value, string purpose) =>
        protector.Protect(JsonSerializer.Serialize(value, JsonOptions), purpose);

    private void LogAccounts(string classCode)
    {
        var accounts = string.Join(
            Environment.NewLine,
            Students.Select(x => $"  {(x.Key == "gabriel" ? "Délégué " : "Élève   ")} {x.Email}"));
        logger.LogInformation(
            """

            ── Swikko · données de développement ──────────────────────
            Classe : {ClassName} · code {ClassCode}
            Mot de passe de tous les comptes : {Password}
            {Accounts}
              En attente {Pending} (demande à valider par le délégué)
            ────────────────────────────────────────────────────────────
            """,
            DevelopmentDataSeeder.ClassName,
            classCode,
            DevelopmentDataSeeder.Password,
            accounts,
            PendingEmail);
    }
}
