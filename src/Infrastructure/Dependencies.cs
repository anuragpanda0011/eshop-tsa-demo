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
            // Connection strings must be sourced from environment variables or
            // Azure Key Vault (via Managed Identity) — never hardcoded in source.
            //
            // Expected env-vars / Key Vault secret names:
            //   ConnectionStrings__CatalogConnection
            //   ConnectionStrings__IdentityConnection
            //
            // Both connection strings must include "Encrypt=True" and
            // (for Azure SQL) can omit a password when Managed Identity is used
            // with the Microsoft.Data.SqlClient token provider.

            var catalogConnection = GetRequiredConnectionString(configuration, "CatalogConnection");
            var identityConnection = GetRequiredConnectionString(configuration, "IdentityConnection");

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
    }

    /// <summary>
    /// Retrieves a required connection string from configuration, throwing a clear
    /// startup error when it is absent so the service fails fast rather than
    /// producing a cryptic runtime exception.
    /// </summary>
    private static string GetRequiredConnectionString(IConfiguration configuration, string name)
    {
        var value = configuration.GetConnectionString(name);
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new InvalidOperationException(
                $"Required connection string '{name}' is not configured. " +
                $"Set it via the environment variable 'ConnectionStrings__{name}' " +
                $"or provision it from Azure Key Vault.");
        }

        return value;
    }
}
