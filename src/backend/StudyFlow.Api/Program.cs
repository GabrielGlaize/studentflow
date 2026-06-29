using StudyFlow.Api.Contracts;
using StudyFlow.Api;
using StudyFlow.Infrastructure;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddProblemDetails();
builder.Services.AddHealthChecks();
builder.Services.AddInfrastructure(builder.Configuration);
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

public partial class Program;
