using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.eShopWeb.Infrastructure.Data;
using Microsoft.eShopWeb.Infrastructure.Identity;
using Microsoft.eShopWeb.PublicApi.AuthEndpoints;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.FunctionalTests.PublicApi;

/// <summary>
/// WebApplicationFactory for the PublicApi project used in functional tests.
/// Replaces Azure SQL connections with in-memory EF Core databases and injects
/// test-only configuration (JWT secret, etc.) via environment variables so that
/// no secrets are baked into source code.
/// </summary>
public class TestApiApplication : WebApplicationFactory<AuthenticateEndpoint>
{
    private const string TestEnvironment = "Testing";

    protected override IHost CreateHost(IHostBuilder builder)
    {
        builder.UseEnvironment(TestEnvironment);

        // Inject test-only configuration values so the API can start without
        // Azure Key Vault being reachable from the test runner.
        builder.ConfigureAppConfiguration((ctx, cfg) =>
        {
            cfg.AddInMemoryCollection(new Dictionary<string, string?>
            {
                // JWT secret used only during tests – must be ≥ 32 chars for HMAC-SHA256.
                // In production this value comes from Azure Key Vault.
                ["JwtSecretKey"] = TestJwtSettings.TestJwtSecret,
                ["JwtValidAlgorithms"] = "HmacSha256",
                // Disable Key Vault in tests
                ["AzureKeyVaultEnabled"] = "false",
            });
        });

        builder.ConfigureServices(services =>
        {
            // ----------------------------------------------------------------
            // Remove any real DbContextOptions registrations and replace with
            // isolated in-memory databases so tests never touch Azure SQL.
            // ----------------------------------------------------------------
            RemoveDescriptors(services,
                typeof(DbContextOptions<CatalogContext>),
                typeof(DbContextOptions<AppIdentityDbContext>));

            services.AddScoped(sp =>
                new DbContextOptionsBuilder<CatalogContext>()
                    .UseInMemoryDatabase("DbForPublicApi")
                    .UseApplicationServiceProvider(sp)
                    .Options);

            services.AddScoped(sp =>
                new DbContextOptionsBuilder<AppIdentityDbContext>()
                    .UseInMemoryDatabase("IdentityDbForPublicApi")
                    .UseApplicationServiceProvider(sp)
                    .Options);
        });

        builder.ConfigureLogging(logging =>
        {
            logging.ClearProviders();
            // Emit structured JSON to stdout so Azure Monitor can ingest test output.
            logging.AddJsonConsole();
        });

        return base.CreateHost(builder);
    }

    private static void RemoveDescriptors(IServiceCollection services, params Type[] serviceTypes)
    {
        var toRemove = services
            .Where(d => serviceTypes.Contains(d.ServiceType))
            .ToList();

        foreach (var descriptor in toRemove)
        {
            services.Remove(descriptor);
        }
    }
}
