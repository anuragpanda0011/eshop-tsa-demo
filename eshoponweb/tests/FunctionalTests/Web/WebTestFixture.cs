using System;
using System.Collections.Generic;
using System.Linq;
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

public class TestApplication : WebApplicationFactory<IBasketViewModelService>
{
    private readonly string _environment = "Development";

    protected override IHost CreateHost(IHostBuilder builder)
    {
        builder.UseEnvironment(_environment);

        builder.ConfigureAppConfiguration((_, config) =>
        {
            // Ensure no secrets are required from Key Vault during tests.
            config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["UseOnlyInMemoryDatabase"] = "true",
                // JWT signing secret for test host — read from env var, never hardcoded.
                ["JwtConfig:Secret"] = Environment.GetEnvironmentVariable("JWT_SECRET_KEY")
                    ?? "test-secret-key-min-32-chars-long!!",
                ["JwtConfig:AllowedAlgorithms:0"] = "HS256"
            });
        });

        builder.ConfigureServices(services =>
        {
            // Remove real DbContext registrations and replace with in-memory databases.
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
            {
                return new DbContextOptionsBuilder<CatalogContext>()
                    .UseInMemoryDatabase("InMemoryDbForTesting")
                    .UseApplicationServiceProvider(sp)
                    .Options;
            });

            services.AddScoped(sp =>
            {
                return new DbContextOptionsBuilder<AppIdentityDbContext>()
                    .UseInMemoryDatabase("Identity")
                    .UseApplicationServiceProvider(sp)
                    .Options;
            });
        });

        builder.ConfigureLogging(logging =>
        {
            logging.ClearProviders();
            // Emit structured JSON logs to stdout so Azure Monitor can ingest them.
            logging.AddConsole(options =>
            {
                options.FormatterName = "json";
            });
        });

        return base.CreateHost(builder);
    }
}
