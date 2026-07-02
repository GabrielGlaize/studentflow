using System.Threading.RateLimiting;
using StudyFlow.Api.Contracts;
using StudyFlow.Api;
using StudyFlow.Infrastructure;

LoadLocalEnvironmentFile();

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddProblemDetails();
builder.Services.AddHealthChecks();
builder.Services.AddInfrastructure(builder.Configuration);
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddPolicy("auth-sensitive", context =>
        RateLimitPartition.GetFixedWindowLimiter(
            context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 10,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                AutoReplenishment = true
            }));
});
builder.Services.AddCors(options =>
{
    options.AddPolicy("StudyFlowApp", policy =>
        policy
            .WithOrigins(builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [])
            .AllowAnyHeader()
            .AllowAnyMethod());
});

var app = builder.Build();

if (app.Environment.IsDevelopment() && builder.Configuration.GetValue<bool>("DevelopmentSeed:Enabled"))
{
    await app.Services.SeedDevelopmentDataAsync();
}

app.UseExceptionHandler();
app.UseCors("StudyFlowApp");
app.UseRateLimiter();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHealthChecks("/health");
app.MapGet("/api/status", () => Results.Ok(new ApiStatusResponse(
    "StudyFlow.Api",
    "ok",
    typeof(Program).Assembly.GetName().Version?.ToString() ?? "unknown",
    DateTimeOffset.UtcNow)));

app.Run();

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
