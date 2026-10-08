using System.Net;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.EntityFrameworkCore;
using Microsoft.OpenApi.Models;
using StudyFlow.Api.Contracts;
using StudyFlow.Api;
using StudyFlow.Infrastructure;
using StudyFlow.Infrastructure.Persistence;

LoadLocalEnvironmentFile();

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<StudyFlowExceptionHandler>();
builder.Services.AddHealthChecks();
builder.Services.AddInfrastructure(builder.Configuration, builder.Environment);
builder.Services.AddStudyFlowRateLimiting(builder.Configuration);
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    // Derrière le reverse proxy du NAS, l'IP vue par l'API est celle du proxy : sans ces en-têtes,
    // tous les utilisateurs partageraient la même limite de requêtes.
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    foreach (var proxy in builder.Configuration.GetSection("ReverseProxy:KnownProxies").Get<string[]>() ?? [])
    {
        options.KnownProxies.Add(IPAddress.Parse(proxy));
    }

    foreach (var network in builder.Configuration.GetSection("ReverseProxy:KnownNetworks").Get<string[]>() ?? [])
    {
        options.KnownNetworks.Add(ParseNetwork(network));
    }
});
builder.Services.AddCors(options =>
{
    options.AddPolicy("StudyFlowApp", policy =>
        policy
            .WithOrigins(builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [])
            .WithHeaders("Accept", "Authorization", "Content-Type")
            .WithMethods("GET", "POST", "PUT", "DELETE"));
});

var openApiEnabled = builder.Configuration.GetValue<bool>("OpenApi:Enabled");
if (openApiEnabled)
{
    builder.Services.AddEndpointsApiExplorer();
    builder.Services.AddSwaggerGen(options =>
    {
        options.SwaggerDoc("v1", new OpenApiInfo { Title = "StudyFlow API", Version = "v1" });
        options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
        {
            Description = "Access token JWT obtenu via /api/v1/auth/login.",
            Type = SecuritySchemeType.Http,
            Scheme = "bearer",
            BearerFormat = "JWT"
        });
        options.AddSecurityRequirement(new OpenApiSecurityRequirement
        {
            [new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" }
            }] = []
        });
    });
}

var app = builder.Build();

// Commande ponctuelle du NAS (scripts/nas_seed_demo.sh) : remplit la base de démo puis s'arrête.
if (args.Contains("--seed-development-data", StringComparer.OrdinalIgnoreCase))
{
    await app.Services.SeedDevelopmentDataAsync();
    return;
}

app.Logger.LogInformation("StudyFlow.Api starting in {Environment} environment.", app.Environment.EnvironmentName);

app.UseForwardedHeaders();

app.Use(async (context, next) =>
{
    context.Response.Headers.Append("X-Content-Type-Options", "nosniff");
    context.Response.Headers.Append("X-Frame-Options", "DENY");
    context.Response.Headers.Append("Referrer-Policy", "strict-origin-when-cross-origin");

    // L'API ne renvoie que du JSON ; le site public (wwwroot) charge ses propres fichiers ;
    // l'interface Swagger a besoin de ses scripts intégrés.
    if (context.Request.Path.StartsWithSegments("/api"))
    {
        context.Response.Headers.Append("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'");
    }
    else if (!context.Request.Path.StartsWithSegments("/swagger"))
    {
        context.Response.Headers.Append(
            "Content-Security-Policy",
            "default-src 'self'; base-uri 'self'; object-src 'none'; frame-ancestors 'none'; form-action 'self'; img-src 'self' data:; script-src 'self'; style-src 'self'; connect-src 'self'");
    }

    await next();
});

var usesDevelopmentSeed = app.Environment.IsDevelopment()
    && builder.Configuration.GetValue<bool>("DevelopmentSeed:Enabled");

if (builder.Configuration.GetValue<bool>("Database:ApplyMigrationsOnStartup") && !usesDevelopmentSeed)
{
    await ApplyDatabaseMigrationsAsync(app.Services);
}

if (usesDevelopmentSeed)
{
    await app.Services.SeedDevelopmentDataAsync();
}

app.UseExceptionHandler();

if (openApiEnabled)
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseDefaultFiles();
app.UseStaticFiles();

app.UseCors("StudyFlowApp");

// Authentification avant la limitation : la politique ClassJoin compte par utilisateur.
app.UseAuthentication();
app.UseRateLimiter();
app.UseAuthorization();

app.MapControllers();
app.MapHealthChecks("/health");
app.MapGet("/api/status", () => Results.Ok(new ApiStatusResponse(
    "StudyFlow.Api",
    "ok",
    typeof(Program).Assembly.GetName().Version?.ToString() ?? "unknown",
    DateTimeOffset.UtcNow)));
app.MapGet("/alternance", async (HttpContext context) =>
{
    context.Response.ContentType = "text/html; charset=utf-8";
    await context.Response.SendFileAsync(Path.Combine(
        app.Environment.WebRootPath,
        "alternance",
        "index.html"));
}).ExcludeFromDescription();

// Pages du site public, absentes de la documentation de l'API.
app.MapGet("/alternnace", () => Results.Redirect("/alternance")).ExcludeFromDescription();
app.MapGet("/alternnace/", () => Results.Redirect("/alternance")).ExcludeFromDescription();

app.Run();

static Microsoft.AspNetCore.HttpOverrides.IPNetwork ParseNetwork(string value)
{
    var parts = value.Split('/', 2, StringSplitOptions.TrimEntries);
    if (parts.Length != 2 || !IPAddress.TryParse(parts[0], out var prefix) || !int.TryParse(parts[1], out var prefixLength))
    {
        throw new InvalidOperationException($"ReverseProxy:KnownNetworks contient une valeur invalide : '{value}' (attendu : 172.16.0.0/12).");
    }

    return new Microsoft.AspNetCore.HttpOverrides.IPNetwork(prefix, prefixLength);
}

static async Task ApplyDatabaseMigrationsAsync(IServiceProvider services)
{
    using var scope = services.CreateScope();
    var dbContext = scope.ServiceProvider.GetRequiredService<StudyFlowDbContext>();
    await dbContext.Database.MigrateAsync();
}

static void LoadLocalEnvironmentFile()
{
    var environmentFilePath = FindEnvironmentFile();
    if (environmentFilePath is null) return;

    foreach (var rawLine in File.ReadAllLines(environmentFilePath))
    {
        var line = rawLine.Trim();
        if (string.IsNullOrWhiteSpace(line) || line.StartsWith('#')) continue;
        if (line.StartsWith("export ", StringComparison.OrdinalIgnoreCase))
        {
            line = line["export ".Length..].Trim();
        }

        var separatorIndex = line.IndexOf('=');
        if (separatorIndex <= 0) continue;

        var key = line[..separatorIndex].Trim();
        var value = line[(separatorIndex + 1)..].Trim();
        if (value.Length >= 2
            && ((value.StartsWith('"') && value.EndsWith('"'))
                || (value.StartsWith('\'') && value.EndsWith('\''))))
        {
            value = value[1..^1];
        }

        // A real system environment variable stays stronger than the local .env file.
        if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable(key)))
        {
            Environment.SetEnvironmentVariable(key, value);
        }
    }
}

static string? FindEnvironmentFile()
{
    foreach (var startPath in new[] { Directory.GetCurrentDirectory(), AppContext.BaseDirectory })
    {
        var directory = new DirectoryInfo(startPath);
        while (directory is not null)
        {
            var candidate = Path.Combine(directory.FullName, ".env");
            if (File.Exists(candidate)) return candidate;
            directory = directory.Parent;
        }
    }

    return null;
}

public partial class Program;
