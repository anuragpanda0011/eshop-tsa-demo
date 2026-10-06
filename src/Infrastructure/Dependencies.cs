using System;
using Microsoft.EntityFrameworkCore;
using Microsoft.eShopWeb.Infrastructure.Data;
using Microsoft.eShopWeb.Infrastructure.Identity;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.Infrastructure;

public static class Dependencies
{
    public static void ConfigureServices(IConfiguration configuration, IServiceCollection services)
    {
        // ------------------------------------------------------------------
        // In-memory mode — used for unit tests / local dev without a DB.
        // ------------------------------------------------------------------
        bool useOnlyInMemoryDatabase = false;
        if (configuration["UseOnlyInMemoryDatabase"] != null)
        {
            useOnlyInMemoryDatabase = bool.Parse(configuration["UseOnlyInMemoryDatabase"]!);
        }

        if (useOnlyInMemoryDatabase)
        {
            services.AddDbContext<CatalogContext>(c =>
                c.UseInMemoryDatabase("Catalog"));

            services.AddDbContext<AppIdentityDbContext>(options =>
                options.UseInMemoryDatabase("Identity"));
        }
        else
        {
            // ------------------------------------------------------------------
            // Production / staging path — connection strings come from
            // Azure Key Vault (via Managed Identity + AddAzureKeyVault in the
            // host builder) or from environment variables; they are NEVER
            // hardcoded here.  Both connection strings must include
            // "Encrypt=True" (enforced by Azure SQL's default TLS requirement).
            // ------------------------------------------------------------------
            var catalogConnection = configuration.GetConnectionString("CatalogConnection")
                ?? throw new InvalidOperationException(
                    "Connection string 'CatalogConnection' is not configured. " +
                    "Set it via Azure Key Vault, an environment variable, or appsettings.");

            var identityConnection = configuration.GetConnectionString("IdentityConnection")
                ?? throw new InvalidOperationException(
                    "Connection string 'IdentityConnection' is not configured. " +
                    "Set it via Azure Key Vault, an environment variable, or appsettings.");

            // Enforce TLS in production: the connection string must not disable encryption.
            EnsureTlsEnforced(catalogConnection, "CatalogConnection");
            EnsureTlsEnforced(identityConnection, "IdentityConnection");

            services.AddDbContext<CatalogContext>(c =>
                c.UseSqlServer(catalogConnection, sqlOptions =>
                {
                    sqlOptions.EnableRetryOnFailure(
                        maxRetryCount: 5,
                        maxRetryDelay: TimeSpan.FromSeconds(30),
                        errorNumbersToAdd: null);
                }));

            services.AddDbContext<AppIdentityDbContext>(options =>
                options.UseSqlServer(identityConnection, sqlOptions =>
                {
                    sqlOptions.EnableRetryOnFailure(
                        maxRetryCount: 5,
                        maxRetryDelay: TimeSpan.FromSeconds(30),
                        errorNumbersToAdd: null);
                }));
        }

        // ------------------------------------------------------------------
        // Redis distributed cache — used for basket counts, catalog pages,
        // session, and idempotency keys.  The connection string is sourced
        // from Key Vault / env vars; TLS (rediss://) is required in production.
        // ------------------------------------------------------------------
        var redisConnection = configuration.GetConnectionString("RedisConnection");
        if (!string.IsNullOrWhiteSpace(redisConnection))
        {
            // Enforce rediss:// (TLS) when not running in local/dev mode.
            var environment = configuration["ASPNETCORE_ENVIRONMENT"] ?? "Production";
            if (!string.Equals(environment, "Development", StringComparison.OrdinalIgnoreCase)
                && !redisConnection.StartsWith("rediss://", StringComparison.OrdinalIgnoreCase)
                // StackExchange.Redis format with ssl=true is also acceptable.
                && !redisConnection.Contains("ssl=true", StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException(
                    "Redis connection string must use TLS (rediss:// or ssl=true) in non-Development environments.");
            }

            services.AddStackExchangeRedisCache(options =>
            {
                options.Configuration = redisConnection;
                options.InstanceName = "eShopWeb:";
            });
        }
        else
        {
            // Fall back to in-memory distributed cache when Redis is not configured
            // (e.g. local development without Docker).
            services.AddDistributedMemoryCache();
        }
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    /// <summary>
    /// Verifies that the SQL connection string does not explicitly disable
    /// encryption, which Azure SQL requires by default.
    /// Throws <see cref="InvalidOperationException"/> if encryption is disabled.
    /// </summary>
    private static void EnsureTlsEnforced(string connectionString, string name)
    {
        // Azure SQL always encrypts; we just guard against an explicit opt-out.
        if (connectionString.Contains("Encrypt=False", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(
                $"Connection string '{name}' must not disable TLS encryption (Encrypt=False). " +
                "Azure SQL requires encrypted connections.");
        }
    }
}
