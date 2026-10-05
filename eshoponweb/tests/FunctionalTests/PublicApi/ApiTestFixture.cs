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

public class TestApiApplication : WebApplicationFactory<AuthenticateEndpoint>
{
    private readonly string _environment = "Testing";

    protected override IHost CreateHost(IHostBuilder builder)
    {
        builder.UseEnvironment(_environment);

        builder.ConfigureAppConfiguration((context, config) =>
        {
            // Override configuration for testing — no secrets needed from Key Vault
            config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["UseOnlyInMemoryDatabase"] = "true",
                // JWT secret pulled from env var in production; use a test value here
                ["JwtConfig:Secret"] = Environment.GetEnvironmentVariable("JWT_SECRET_KEY")
                    ?? "test-secret-key-min-32-chars-long!!",
                ["JwtConfig:AllowedAlgorithms:0"] = "HS256"
            });
        });

        builder.ConfigureServices(services =>
        {
            // Remove any existing DbContext registrations
            var catalogDescriptors = services
                .Where(d => d.ServiceType == typeof(DbContextOptions<CatalogContext>))
                .ToList();
            var identityDescriptors = services
                .Where(d => d.ServiceType == typeof(DbContextOptions<AppIdentityDbContext>))
                .ToList();

            foreach (var d in catalogDescriptors.Concat(identityDescriptors))
            {
                services.Remove(d);
            }

            services.AddScoped(sp =>
            {
                return new DbContextOptionsBuilder<CatalogContext>()
                    .UseInMemoryDatabase("DbForPublicApi")
                    .UseApplicationServiceProvider(sp)
                    .Options;
            });

            services.AddScoped(sp =>
            {
                return new DbContextOptionsBuilder<AppIdentityDbContext>()
                    .UseInMemoryDatabase("IdentityDbForPublicApi")
                    .UseApplicationServiceProvider(sp)
                    .Options;
            });
        });

        builder.ConfigureLogging(logging =>
        {
            logging.ClearProviders();
            logging.AddConsole();
        });

        return base.CreateHost(builder);
    }
}
