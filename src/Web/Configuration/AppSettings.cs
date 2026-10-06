using System;
using System.Collections.Generic;
using Microsoft.Extensions.Configuration;

namespace Microsoft.eShopOnWeb.Web.Configuration;

/// <summary>
/// Strongly-typed, startup-validated settings for the Web application.
/// All values originate from environment variables / Key Vault.
/// </summary>
public sealed class AppSettings
{
    // ── Allowed JWT algorithms ────────────────────────────────────────────
    private static readonly HashSet<string> _allowedJwtAlgorithms =
        new(StringComparer.OrdinalIgnoreCase) { "HS256", "HS384", "HS512" };

    // ── Required connection strings ───────────────────────────────────────
    public string CatalogConnection { get; private init; } = string.Empty;
    public string IdentityConnection { get; private init; } = string.Empty;

    // ── Redis ─────────────────────────────────────────────────────────────
    public string RedisConnectionString { get; private init; } = string.Empty;

    // ── Security ─────────────────────────────────────────────────────────
    public string JwtSecretKey { get; private init; } = string.Empty;
    public string JwtAlgorithm { get; private init; } = "HS256";

    // ── CORS ─────────────────────────────────────────────────────────────
    public IReadOnlyList<string> CorsOrigins { get; private init; } = Array.Empty<string>();

    // ── Allowed hosts ────────────────────────────────────────────────────
    public IReadOnlyList<string> AllowedHosts { get; private init; } = Array.Empty<string>();

    // ── Feature toggles / tunables ────────────────────────────────────────
    public bool IsDebug { get; private init; }
    public int PageSize { get; private init; } = 10;
    public string LogLevel { get; private init; } = "Information";

    // ── Azure Storage ─────────────────────────────────────────────────────
    public string AzureStorageConnectionString { get; private init; } = string.Empty;

    // ── Application Insights ─────────────────────────────────────────────
    public string ApplicationInsightsConnectionString { get; private init; } = string.Empty;

    // ── Service Bus ───────────────────────────────────────────────────────
    public string ServiceBusConnectionString { get; private init; } = string.Empty;
    public string ServiceBusOrderQueueName { get; private init; } = "order-events";

    /// <summary>
    /// Factory: reads from <paramref name="configuration"/>, validates, and returns a
    /// fully-validated <see cref="AppSettings"/> instance.  Raises <see cref="RuntimeError"/>
    /// at startup if any invariant is violated so the process exits fast rather than
    /// failing at runtime.
    /// </summary>
    public static AppSettings LoadAndValidate(IConfiguration configuration)
    {
        bool isDebug = string.Equals(
            configuration["DEBUG"] ?? configuration["ASPNETCORE_ENVIRONMENT"],
            "true", StringComparison.OrdinalIgnoreCase) ||
            string.Equals(
            configuration["ASPNETCORE_ENVIRONMENT"], "Development",
            StringComparison.OrdinalIgnoreCase);

        // ── Required secrets ──────────────────────────────────────────────
        string catalogConn     = Require(configuration, "ConnectionStrings__CatalogConnection");
        string identityConn    = Require(configuration, "ConnectionStrings__IdentityConnection");
        string jwtSecret       = Require(configuration, "Auth__JwtSecret");

        // ── Redis validation ──────────────────────────────────────────────
        string redisConn = configuration["Redis__ConnectionString"]
                        ?? configuration["REDIS_URL"]
                        ?? string.Empty;

        if (string.IsNullOrWhiteSpace(redisConn))
            throw new InvalidOperationException(
                "Redis__ConnectionString is required but was not set.");

        if (!isDebug && !redisConn.StartsWith("rediss://", StringComparison.OrdinalIgnoreCase)
                     && !redisConn.Contains(":6380", StringComparison.Ordinal))
        {
            // Azure Cache for Redis uses port 6380 with TLS — enforce in production
            throw new InvalidOperationException(
                "Redis__ConnectionString must use TLS (rediss:// scheme or port 6380) " +
                "when running outside DEBUG mode.  " +
                "Current value does not satisfy this requirement.");
        }

        // ── JWT algorithm allowlist ───────────────────────────────────────
        string jwtAlg = configuration["JWT_ALGORITHM"] ?? "HS256";
        if (!_allowedJwtAlgorithms.Contains(jwtAlg))
            throw new InvalidOperationException(
                $"JWT_ALGORITHM '{jwtAlg}' is not permitted. " +
                $"Allowed values: {string.Join(", ", _allowedJwtAlgorithms)}. " +
                "The value 'none' is explicitly prohibited.");

        // ── CORS origins ──────────────────────────────────────────────────
        string rawCors = configuration["CORS_ORIGINS"] ?? string.Empty;
        string[] corsOrigins = rawCors
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

        if (!isDebug)
        {
            if (corsOrigins.Length == 0)
                throw new InvalidOperationException(
                    "CORS_ORIGINS must be set to one or more explicit origins in production. " +
                    "Wildcard '*' is not permitted.");

            foreach (string origin in corsOrigins)
            {
                if (origin == "*")
                    throw new InvalidOperationException(
                        "CORS_ORIGINS must not contain '*' in production. " +
                        "Specify explicit origins.");
            }
        }

        // ── Allowed hosts ─────────────────────────────────────────────────
        string rawHosts = configuration["AllowedHosts"] ?? configuration["ALLOWED_HOSTS"] ?? string.Empty;
        string[] allowedHosts = rawHosts
            .Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

        if (!isDebug && allowedHosts.Length == 0)
            throw new InvalidOperationException(
                "AllowedHosts must be configured in production.");

        // ── Optional / defaulted values ───────────────────────────────────
        int pageSize = int.TryParse(configuration["PAGE_SIZE"], out int ps) ? ps : 10;

        return new AppSettings
        {
            CatalogConnection                = catalogConn,
            IdentityConnection               = identityConn,
            JwtSecretKey                     = jwtSecret,
            JwtAlgorithm                     = jwtAlg,
            RedisConnectionString            = redisConn,
            CorsOrigins                      = corsOrigins,
            AllowedHosts                     = allowedHosts,
            IsDebug                          = isDebug,
            PageSize                         = pageSize,
            LogLevel                         = configuration["LOG_LEVEL"] ?? "Information",
            AzureStorageConnectionString     = configuration["AzureStorage__ConnectionString"] ?? string.Empty,
            ApplicationInsightsConnectionString = configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"] ?? string.Empty,
            ServiceBusConnectionString       = configuration["ServiceBus__ConnectionString"] ?? string.Empty,
            ServiceBusOrderQueueName         = configuration["ServiceBus__OrderQueueName"] ?? "order-events",
        };
    }

    // ─────────────────────────────────────────────────────────────────────
    private static string Require(IConfiguration cfg, string key)
    {
        string? value = cfg[key];
        if (string.IsNullOrWhiteSpace(value))
            throw new InvalidOperationException(
                $"Required configuration key '{key}' is missing or empty. " +
                "Ensure it is set via environment variable or Azure Key Vault.");
        return value;
    }
}
