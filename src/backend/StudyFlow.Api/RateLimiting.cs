using System.Globalization;
using System.Security.Claims;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace StudyFlow.Api;

/// <summary>
/// Politiques de limitation. Les valeurs se règlent sans recompiler, par exemple
/// <c>RateLimiting__Credentials__PermitLimit=50</c>.
/// </summary>
public static class RateLimiting
{
    /// <summary>Connexion, inscription, mot de passe oublié : par IP, en complément du verrouillage par compte.</summary>
    public const string Credentials = "auth-credentials";

    /// <summary>Renouvellement de session : appelé automatiquement par l'application, donc bien plus permissif.</summary>
    public const string Refresh = "auth-refresh";

    /// <summary>Saisie d'un code de classe : par utilisateur connecté.</summary>
    public const string ClassJoin = "class-join";

    /// <summary>Recherche publique d'alternances : protège les quotas des API externes.</summary>
    public const string PublicSearch = "public-search";

    public static IServiceCollection AddStudyFlowRateLimiting(this IServiceCollection services, IConfiguration configuration)
    {
        var section = configuration.GetSection("RateLimiting");

        return services.AddRateLimiter(options =>
        {
            options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
            options.OnRejected = async (context, cancellationToken) =>
            {
                if (context.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter))
                {
                    context.HttpContext.Response.Headers.RetryAfter =
                        ((int)Math.Ceiling(retryAfter.TotalSeconds)).ToString(CultureInfo.InvariantCulture);
                }

                await context.HttpContext.Response.WriteAsJsonAsync(new ProblemDetails
                {
                    Status = StatusCodes.Status429TooManyRequests,
                    Title = "Trop de tentatives. Réessaie dans quelques minutes."
                }, cancellationToken);
            };

            AddFixedWindowPolicy(options, Credentials, section.GetSection("Credentials"), PartitionByIp, defaultPermitLimit: 50, defaultWindow: TimeSpan.FromMinutes(10));
            AddFixedWindowPolicy(options, Refresh, section.GetSection("Refresh"), PartitionByIp, defaultPermitLimit: 60, defaultWindow: TimeSpan.FromMinutes(1));
            AddFixedWindowPolicy(options, ClassJoin, section.GetSection("ClassJoin"), PartitionByUser, defaultPermitLimit: 10, defaultWindow: TimeSpan.FromMinutes(15));
            AddFixedWindowPolicy(options, PublicSearch, section.GetSection("PublicSearch"), PartitionByIp, defaultPermitLimit: 30, defaultWindow: TimeSpan.FromMinutes(1));
        });
    }

    private static void AddFixedWindowPolicy(
        RateLimiterOptions options,
        string policyName,
        IConfigurationSection policySection,
        Func<HttpContext, string> partitionKey,
        int defaultPermitLimit,
        TimeSpan defaultWindow)
    {
        var permitLimit = policySection.GetValue("PermitLimit", defaultPermitLimit);
        var window = TimeSpan.FromSeconds(policySection.GetValue("WindowSeconds", (int)defaultWindow.TotalSeconds));

        options.AddPolicy(policyName, context =>
            RateLimitPartition.GetFixedWindowLimiter(
                partitionKey(context),
                _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = permitLimit,
                    Window = window,
                    QueueLimit = 0,
                    AutoReplenishment = true
                }));
    }

    // L'IP réelle n'est disponible que si UseForwardedHeaders fait confiance au reverse proxy (ReverseProxy:KnownNetworks).
    private static string PartitionByIp(HttpContext context) =>
        context.Connection.RemoteIpAddress?.ToString() ?? "unknown";

    private static string PartitionByUser(HttpContext context) =>
        context.User.FindFirstValue(ClaimTypes.NameIdentifier) ?? PartitionByIp(context);
}
