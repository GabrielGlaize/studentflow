using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;
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
                options.Password.RequireNonAlphanumeric = false;
            })
            .AddRoles<IdentityRole<Guid>>()
            .AddEntityFrameworkStores<StudyFlowDbContext>();

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
        services.Configure<LaBonneAlternanceOptions>(configuration.GetSection(LaBonneAlternanceOptions.SectionName));
        services.Configure<NotificationWorkerOptions>(configuration.GetSection(NotificationWorkerOptions.SectionName));

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
            });
        services.AddAuthorization();

        services.AddScoped<ISensitiveDataProtector, SensitiveDataProtector>();
        services.AddScoped<IClassCodeService, ClassCodeService>();
        services.AddScoped<IAuthTokenService, AuthTokenService>();
        services.AddScoped<INotificationReminderPlanner, NotificationReminderPlanner>();
        services.AddScoped<INotificationSender, LoggingNotificationSender>();
        services.AddHostedService<NotificationDispatchWorker>();
        services.AddHttpClient<IApprenticeshipOpportunityProvider, LaBonneAlternanceOpportunityProvider>();

        return services;
    }
}
