using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using StudyFlow.Application.Apprenticeships;
using StudyFlow.Application.Notifications;
using StudyFlow.Application.Security;
using StudyFlow.Infrastructure.Apprenticeships;
using StudyFlow.Infrastructure.Identity;
using StudyFlow.Infrastructure.Notifications;
using StudyFlow.Infrastructure.Persistence;
using StudyFlow.Infrastructure.Security;

namespace StudyFlow.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var connectionString = configuration.GetConnectionString("PostgreSql")
            ?? throw new InvalidOperationException("La chaîne ConnectionStrings:PostgreSql est absente.");

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

        var dataProtection = services.AddDataProtection().SetApplicationName("StudyFlow");
        if (!string.IsNullOrWhiteSpace(securityOptions.DataProtectionKeysPath))
        {
            dataProtection.PersistKeysToFileSystem(new DirectoryInfo(securityOptions.DataProtectionKeysPath));
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

        services.AddScoped<ISensitiveDataProtector, SensitiveDataProtector>();
        services.AddScoped<IClassCodeService, ClassCodeService>();
        services.AddScoped<IAuthTokenService, AuthTokenService>();
        services.AddScoped<IPasswordResetService, PasswordResetService>();
        services.AddScoped<IPasswordResetEmailSender, PasswordResetEmailSender>();
        services.AddScoped<INotificationReminderPlanner, NotificationReminderPlanner>();
        services.AddScoped<INotificationSender, LoggingNotificationSender>();
        services.AddHostedService<NotificationDispatchWorker>();
        services.AddHttpClient<LaBonneAlternanceOpportunityProvider>();
        services.AddHttpClient<AdzunaOpportunityProvider>();
        services.AddHttpClient<FranceTravailOpportunityProvider>();
        services.AddScoped<IApprenticeshipOpportunityProvider, CompositeApprenticeshipOpportunityProvider>();

        return services;
    }
}
