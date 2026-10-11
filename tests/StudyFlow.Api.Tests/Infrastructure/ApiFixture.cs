using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Testcontainers.PostgreSql;

namespace StudyFlow.Api.Tests.Infrastructure;

/// <summary>
/// Un PostgreSQL jetable (Docker) partagé par tous les tests : les contraintes, index filtrés
/// et colonnes jsonb du modèle ne peuvent pas être testés avec une base en mémoire.
/// </summary>
public sealed class ApiFixture : IAsyncLifetime
{
    private readonly PostgreSqlContainer _database = new PostgreSqlBuilder()
        .WithImage("postgres:16-alpine")
        .Build();

    private readonly string _dataProtectionKeysPath =
        Path.Combine(Path.GetTempPath(), $"studyflow-tests-keys-{Guid.NewGuid():N}");

    public ApiFactory Api { get; private set; } = null!;

    public async Task InitializeAsync()
    {
        await _database.StartAsync();
        Api = CreateFactory();
    }

    /// <summary>Instance supplémentaire de l'API sur la même base, avec ses propres réglages.</summary>
    public ApiFactory CreateFactory(
        IReadOnlyDictionary<string, string?>? settings = null,
        Action<IServiceCollection>? configureServices = null) =>
        new(_database.GetConnectionString(), _dataProtectionKeysPath, settings, configureServices);

    public async Task DisposeAsync()
    {
        await Api.DisposeAsync();
        await _database.DisposeAsync();
        if (Directory.Exists(_dataProtectionKeysPath)) Directory.Delete(_dataProtectionKeysPath, recursive: true);
    }
}

[CollectionDefinition(Name)]
public sealed class ApiCollection : ICollectionFixture<ApiFixture>
{
    public const string Name = "api";
}

public sealed class ApiFactory(
    string connectionString,
    string dataProtectionKeysPath,
    IReadOnlyDictionary<string, string?>? settings,
    Action<IServiceCollection>? configureServices) : WebApplicationFactory<Program>
{
    // Avant le premier démarrage de l'API : le fichier .env local (vraies clés Adzuna, etc.)
    // ferait interroger les vrais services pendant les tests.
    static ApiFactory() => Environment.SetEnvironmentVariable("STUDYFLOW_IGNORE_DOTENV", "1");

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");

        var defaults = new Dictionary<string, string?>
        {
            ["ConnectionStrings:PostgreSql"] = connectionString,
            ["Jwt:SigningKey"] = "tests-only-signing-key-0123456789abcdef",
            ["Security:LookupKey"] = "tests-only-lookup-key-0123456789abcdef",
            ["Security:DataProtectionKeysPath"] = dataProtectionKeysPath,
            ["Database:ApplyMigrationsOnStartup"] = "true",
            // Les tests d'inscription par code (EmailVerificationTests) le réactivent.
            ["Security:RequireEmailVerification"] = "false",
            ["NotificationWorker:Enabled"] = "false",
            ["RateLimiting:Credentials:PermitLimit"] = "100000",
            ["RateLimiting:Refresh:PermitLimit"] = "100000",
            ["RateLimiting:ClassJoin:PermitLimit"] = "100000",
            ["RateLimiting:PublicSearch:PermitLimit"] = "100000"
        };

        foreach (var (key, value) in settings ?? new Dictionary<string, string?>())
        {
            defaults[key] = value;
        }

        foreach (var (key, value) in defaults)
        {
            builder.UseSetting(key, value);
        }

        if (configureServices is not null)
        {
            builder.ConfigureTestServices(configureServices);
        }
    }
}
