using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using StudyFlow.Application.Accounts;
using StudyFlow.Application.Apprenticeships;
using StudyFlow.Application.Notifications;
using StudyFlow.Application.Security;
using StudyFlow.Application.Time;
using StudyFlow.Infrastructure.Apprenticeships;
using StudyFlow.Infrastructure.Identity;
using StudyFlow.Infrastructure.Notifications;
using StudyFlow.Infrastructure.Persistence;
using StudyFlow.Infrastructure.Security;
using StudyFlow.Infrastructure.Time;

namespace StudyFlow.Infrastructure;

public static class DependencyInjection
{
    private static readonly TimeSpan ApprenticeshipProviderTimeout = TimeSpan.FromSeconds(8);

    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration,
        IHostEnvironment environment)
    {
        // appsettings.json contient une valeur vide : sans ce contrôle, l'API démarre puis échoue à la première requête.
        var connectionString = configuration.GetConnectionString("PostgreSql");
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            throw new InvalidOperationException("La chaîne ConnectionStrings:PostgreSql est absente.");
        }

        services.AddDbContext<StudyFlowDbContext>(options =>
            options.UseNpgsql(connectionString, npgsql =>
                npgsql.MigrationsAssembly(typeof(StudyFlowDbContext).Assembly.FullName)));

        services
            .AddIdentityCore<ApplicationUser>(options =>
            {
                options.User.RequireUniqueEmail = true;
                options.Password.RequiredLength = 10;
                options.Password.RequireDigit = true;
                options.Password.RequireLowercase = true;
                options.Password.RequireUppercase = true;
                options.Password.RequireNonAlphanumeric = true;

                // Protection par compte contre la recherche de mot de passe : la limite par IP seule
                // pénaliserait toute une classe derrière le même Wi-Fi.
                options.Lockout.AllowedForNewUsers = true;
                options.Lockout.MaxFailedAccessAttempts = 5;
                options.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(15);
            })
            .AddRoles<IdentityRole<Guid>>()
            .AddEntityFrameworkStores<StudyFlowDbContext>()
            .AddDefaultTokenProviders();

        var jwtOptions = configuration.GetSection(JwtOptions.SectionName).Get<JwtOptions>()
            ?? throw new InvalidOperationException("La configuration JWT est absente.");
        if (Encoding.UTF8.GetByteCount(jwtOptions.SigningKey) < 32)
        {
            throw new InvalidOperationException("Jwt:SigningKey doit contenir au moins 32 octets.");
        }

        var securityOptions = configuration.GetSection(SecurityOptions.SectionName).Get<SecurityOptions>()
            ?? throw new InvalidOperationException("La configuration Security est absente.");
        if (Encoding.UTF8.GetByteCount(securityOptions.LookupKey) < 32)
        {
            throw new InvalidOperationException("Security:LookupKey doit contenir au moins 32 octets.");
        }

        services.Configure<JwtOptions>(configuration.GetSection(JwtOptions.SectionName));
        services.Configure<SecurityOptions>(configuration.GetSection(SecurityOptions.SectionName));
        services.Configure<AdzunaOptions>(configuration.GetSection(AdzunaOptions.SectionName));
        services.Configure<LaBonneAlternanceOptions>(configuration.GetSection(LaBonneAlternanceOptions.SectionName));
        services.Configure<FranceTravailOptions>(configuration.GetSection(FranceTravailOptions.SectionName));
        services.Configure<NotificationWorkerOptions>(configuration.GetSection(NotificationWorkerOptions.SectionName));
        services.Configure<EmailOptions>(configuration.GetSection(EmailOptions.SectionName));
        services.Configure<SchoolTimeOptions>(configuration.GetSection(SchoolTimeOptions.SectionName));

        var dataProtection = services.AddDataProtection().SetApplicationName("StudyFlow");
        if (!string.IsNullOrWhiteSpace(securityOptions.DataProtectionKeysPath))
        {
            dataProtection.PersistKeysToFileSystem(new DirectoryInfo(securityOptions.DataProtectionKeysPath));
        }
        else if (!environment.IsDevelopment())
        {
            // Sans dossier persistant, les clés vivent dans le conteneur : le recréer rendrait
            // définitivement illisibles les cours, professeurs, messages et codes de classe chiffrés.
            throw new InvalidOperationException(
                "Security:DataProtectionKeysPath est obligatoire hors développement. "
                + "Indique un dossier monté sur un volume persistant (et sauvegardé avec la base).");
        }

        services
            .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(options =>
            {
                options.MapInboundClaims = false;
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidIssuer = jwtOptions.Issuer,
                    ValidateAudience = true,
                    ValidAudience = jwtOptions.Audience,
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtOptions.SigningKey)),
                    ValidateLifetime = true,
                    ClockSkew = TimeSpan.FromSeconds(30),
                    NameClaimType = "sub",
                    RoleClaimType = System.Security.Claims.ClaimTypes.Role
                };
                options.Events = new JwtBearerEvents
                {
                    OnTokenValidated = async context =>
                    {
                        const string securityStampClaimType = "sst";
                        var principal = context.Principal;
                        var userId = principal?.FindFirstValue(ClaimTypes.NameIdentifier)
                            ?? principal?.FindFirstValue(JwtRegisteredClaimNames.Sub);
                        var tokenSecurityStamp = principal?.FindFirstValue(securityStampClaimType);

                        if (!Guid.TryParse(userId, out _) || string.IsNullOrWhiteSpace(tokenSecurityStamp))
                        {
                            context.Fail("Jeton invalide.");
                            return;
                        }

                        var userManager = context.HttpContext.RequestServices.GetRequiredService<UserManager<ApplicationUser>>();
                        var user = await userManager.FindByIdAsync(userId);
                        if (user is null || !user.IsActive)
                        {
                            context.Fail("Compte introuvable ou desactive.");
                            return;
                        }

                        var currentSecurityStamp = await userManager.GetSecurityStampAsync(user);
                        if (!string.Equals(tokenSecurityStamp, currentSecurityStamp, StringComparison.Ordinal))
                        {
                            context.Fail("Jeton expire par changement de securite.");
                        }
                    }
                };
            });
        services.AddAuthorization();

        services.TryAddSingleton(TimeProvider.System);
        services.AddSingleton<ISchoolClock, SchoolClock>();
        services.AddScoped<ISensitiveDataProtector, SensitiveDataProtector>();
        services.AddScoped<IClassCodeService, ClassCodeService>();
        services.AddScoped<IAuthTokenService, AuthTokenService>();
        services.AddScoped<IPasswordResetService, PasswordResetService>();
        services.AddScoped<IPasswordResetEmailSender, PasswordResetEmailSender>();
        services.AddScoped<IAccountDeletionService, AccountDeletionService>();
        services.AddScoped<INotificationReminderPlanner, NotificationReminderPlanner>();
        AddPushNotifications(services, configuration);
        services.AddHostedService<NotificationDispatchWorker>();

        // Délai court : une source lente ne doit pas bloquer la recherche publique (100 s par défaut).
        services.AddHttpClient<LaBonneAlternanceOpportunityProvider>(client => client.Timeout = ApprenticeshipProviderTimeout);
        services.AddHttpClient<AdzunaOpportunityProvider>(client => client.Timeout = ApprenticeshipProviderTimeout);
        services.AddHttpClient<FranceTravailOpportunityProvider>(client => client.Timeout = ApprenticeshipProviderTimeout);
        services.AddSingleton<FranceTravailTokenCache>();
        services.AddSingleton<ApprenticeshipSearchCache>();
        services.AddScoped<CompositeApprenticeshipOpportunityProvider>();
        services.AddScoped<IApprenticeshipOpportunityProvider, CachedApprenticeshipOpportunityProvider>();

        return services;
    }

    private static void AddPushNotifications(IServiceCollection services, IConfiguration configuration)
    {
        var firebaseOptions = configuration.GetSection(FirebaseOptions.SectionName).Get<FirebaseOptions>() ?? new FirebaseOptions();
        if (!firebaseOptions.IsConfigured)
        {
            services.AddScoped<IPushNotificationSender, LoggingPushNotificationSender>();
            return;
        }

        // Erreur claire au démarrage plutôt qu'au premier rappel envoyé.
        if (!File.Exists(firebaseOptions.CredentialsPath))
        {
            throw new InvalidOperationException(
                $"Firebase:CredentialsPath pointe vers un fichier introuvable : {firebaseOptions.CredentialsPath}");
        }

        services.AddSingleton(_ => FirebaseApp.Create(
            new AppOptions
            {
                Credential = CredentialFactory
                    .FromFile<ServiceAccountCredential>(firebaseOptions.CredentialsPath!)
                    .ToGoogleCredential()
            },
            "studyflow"));
        services.AddSingleton(provider => FirebaseMessaging.GetMessaging(provider.GetRequiredService<FirebaseApp>()));
        services.AddScoped<IPushNotificationSender, FcmPushNotificationSender>();
    }
}
