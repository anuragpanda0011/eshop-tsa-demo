using System;
using System.Collections.Generic;
using Microsoft.Extensions.Configuration;

namespace Microsoft.eShopOnWeb.PublicApi.Configuration;

/// <summary>
/// Strongly-typed, startup-validated settings for the Public API application.
/// Mirrors the security invariants enforced in Web/Configuration/AppSettings.cs.
/// </summary>
public sealed class ApiSettings
{
    private static readonly HashSet<string> _allowedJwtAlgorithms =
        new(StringComparer.OrdinalIgnoreCase) { "HS256", "HS384", "HS512" };

    public string CatalogConnection { get; private init; } = string.Empty;
    public string IdentityConnection { get; private init; } = string.Empty;
    public string RedisConnectionString { get; private init; } = string.Empty;
    public string JwtSecretKey { get; private init; } = string.Empty;
    public string JwtAlgorithm { get; private init; } = "HS256";
    public IReadOnlyList<string> CorsOrigins { get; private init; } = Array.Empty<string>();
    public IReadOnlyList<string> AllowedHosts { get; private init; } = Array.Empty<string>();
    public bool IsDebug { get; private init; }
    public int PageSize { get; private init; } = 10;
    public string LogLevel { get; private init; } = "Information";
    public string ApplicationInsightsConnectionString { get; private init; } = string.Empty;
    public string ServiceBusConnectionString { get; private init; } = string.Empty;
    public string ServiceBusOrderQueueName { get; private init; } = "order-events";

    public static ApiSettings LoadAndValidate(IConfiguration configuration)
    {
        bool isDebug = string.Equals(
            configuration["DEBUG"] ?? string.Empty, "true",
            StringComparison.OrdinalIgnoreCase) ||
            string.Equals(
            configuration["ASPNETCORE_ENVIRONMENT"], "Development",
            StringComparison.OrdinalIgnoreCase);

        string catalogConn  = Require(configuration, "ConnectionStrings__CatalogConnection");
        string identityConn = Require(configuration, "ConnectionStrings__IdentityConnection");
        string jwtSecret    = Require(configuration, "Auth__JwtSecret");

        string redisConn = configuration["Redis__ConnectionString"]
                        ?? configuration["REDIS_URL"]
                        ?? string.Empty;

        if (string.IsNullOrWhiteSpace(redisConn))
            throw new InvalidOperationException("Redis__ConnectionString is required.");

        if (!isDebug && !redisConn.StartsWith("rediss://", StringComparison.OrdinalIgnoreCase)
                     && !redisConn.Contains(":6380", StringComparison.Ordinal))
        {
            throw new InvalidOperationException(
                "Redis__ConnectionString must use TLS (rediss:// or port 6380) in production.");
        }

        string jwtAlg = configuration["JWT_ALGORITHM"] ?? "HS256";
        if (!_allowedJwtAlgorithms.Contains(jwtAlg))
            throw new InvalidOperationException(
                $"JWT_ALGORITHM '{jwtAlg}' is not in the allowed set " +
                $"{{ {string.Join(", ", _allowedJwtAlgorithms)} }}. " +
                "Value 'none' is explicitly prohibited.");

        string rawCors = configuration["CORS_ORIGINS"] ?? string.Empty;
        string[] corsOrigins = rawCors
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

        if (!isDebug)
        {
            if (corsOrigins.Length == 0)
                throw new InvalidOperationException(
                    "CORS_ORIGINS must contain at least one explicit origin in production.");
            foreach (string o in corsOrigins)
                if (o == "*")
                    throw new InvalidOperationException("Wildcard '*' is not permitted in CORS_ORIGINS.");
        }

        string rawHosts = configuration["AllowedHosts"] ?? configuration["ALLOWED_HOSTS"] ?? string.Empty;
        string[] allowedHosts = rawHosts
            .Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

        if (!isDebug && allowedHosts.Length == 0)
            throw new InvalidOperationException("AllowedHosts must be configured in production.");

        int pageSize = int.TryParse(configuration["PAGE_SIZE"], out int ps) ? ps : 10;

        return new ApiSettings
        {
            CatalogConnection                   = catalogConn,
            IdentityConnection                  = identityConn,
            JwtSecretKey                        = jwtSecret,
            JwtAlgorithm                        = jwtAlg,
            RedisConnectionString               = redisConn,
            CorsOrigins                         = corsOrigins,
            AllowedHosts                        = allowedHosts,
            IsDebug                             = isDebug,
            PageSize                            = pageSize,
            LogLevel                            = configuration["LOG_LEVEL"] ?? "Information",
            ApplicationInsightsConnectionString = configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"] ?? string.Empty,
            ServiceBusConnectionString          = configuration["ServiceBus__ConnectionString"] ?? string.Empty,
            ServiceBusOrderQueueName            = configuration["ServiceBus__OrderQueueName"] ?? "order-events",
        };
    }

    private static string Require(IConfiguration cfg, string key)
    {
        string? value = cfg[key];
        if (string.IsNullOrWhiteSpace(value))
            throw new InvalidOperationException(
                $"Required configuration key '{key}' is missing or empty.");
        return value;
    }
}
