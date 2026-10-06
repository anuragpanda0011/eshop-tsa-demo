using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.eShopWeb.Infrastructure.Data;
using Microsoft.eShopWeb.Infrastructure.Identity;
using Microsoft.eShopWeb.Web.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.FunctionalTests.Web;

/// <summary>
/// Shared WebApplicationFactory for the Web (MVC) project.
///
/// - Replaces Azure SQL connections with isolated EF Core in-memory databases.
/// - Injects test-only configuration (JWT secret, Key Vault disabled, etc.)
///   so that the test runner does not require Azure connectivity.
/// - All secrets are resolved from environment variables; no hardcoded values
///   reach production.
/// </summary>
public class TestApplication : WebApplicationFactory<IBasketViewModelService>
{
    private const string TestEnvironment = "Development";

    protected override IHost CreateHost(IHostBuilder builder)
    {
        builder.UseEnvironment(TestEnvironment);

        // Supply test-only configuration values.  In production these come from
        // Azure Key Vault via Managed Identity.
        builder.ConfigureAppConfiguration((_, cfg) =>
        {
            cfg.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["JwtSecretKey"]          = FunctionalTests.PublicApi.TestJwtSettings.TestJwtSecret,
                ["JwtValidAlgorithms"]    = "HmacSha256",
                ["AzureKeyVaultEnabled"]  = "false",
                // Disable Redis in tests – no distributed cache required.
                ["Redis:ConnectionString"] = string.Empty,
            });
        });

        builder.ConfigureServices(services =>
        {
            // ------------------------------------------------------------------
            // Remove real DbContextOptions and replace with in-memory variants.
            // ------------------------------------------------------------------
            var descriptors = services
                .Where(d =>
                    d.ServiceType == typeof(DbContextOptions<CatalogContext>) ||
                    d.ServiceType == typeof(DbContextOptions<AppIdentityDbContext>))
                .ToList();

            foreach (var descriptor in descriptors)
            {
                services.Remove(descriptor);
            }

            services.AddScoped(sp =>
                new DbContextOptionsBuilder<CatalogContext>()
                    .UseInMemoryDatabase("InMemoryDbForTesting")
                    .UseApplicationServiceProvider(sp)
                    .Options);

            services.AddScoped(sp =>
                new DbContextOptionsBuilder<AppIdentityDbContext>()
                    .UseInMemoryDatabase("Identity")
                    .UseApplicationServiceProvider(sp)
                    .Options);
        });

        builder.ConfigureLogging(logging =>
        {
            logging.ClearProviders();
            // Structured JSON logs so Azure Monitor / Log Analytics can ingest
            // output from CI pipelines that run these functional tests.
            logging.AddJsonConsole();
        });

        return base.CreateHost(builder);
    }
}
