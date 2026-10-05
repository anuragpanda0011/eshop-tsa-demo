using System;
using System.Collections.Generic;
using Microsoft.Extensions.Configuration;

namespace Microsoft.eShopOnWeb.PublicApi.Configuration;

/// <summary>
/// Strongly-typed, validated settings for the PublicApi process.
/// </summary>
public sealed class ApiSettings
{
    private static readonly HashSet<string> AllowedJwtAlgorithms =
        new(StringComparer.OrdinalIgnoreCase) { "HS256", "HS384", "HS512" };

    // ── Secrets ───────────────────────────────────────────────────────────
    public string CatalogConnectionString { get; init; }
    public string IdentityConnectionString { get; init; }
    public string JwtSecretKey { get; init; }

    // ── JWT ───────────────────────────────────────────────────────────────
    public string JwtAlgorithm { get; init; } = "HS256";
    public string JwtIssuer    { get; init; } = string.Empty;
    public string JwtAudience  { get; init; } = string.Empty;

    // ── Redis ─────────────────────────────────────────────────────────────
    public string RedisConnectionString { get; init; }

    // ── Feature flags ─────────────────────────────────────────────────────
    public bool UseAzureKeyVault { get; init; } = true;
    public bool Debug            { get; init; } = false;

    // ── Observability ─────────────────────────────────────────────────────
    public string LogLevel { get; init; } = "Information";

    // ── Pagination ────────────────────────────────────────────────────────
    public int PageSize { get; init; } = 10;

    // ── CORS ──────────────────────────────────────────────────────────────
    public IReadOnlyList<string> CorsOrigins { get; init; } = Array.Empty<string>();

    // ── Host ──────────────────────────────────────────────────────────────
    public IReadOnlyList<string> AllowedHosts { get; init; } = Array.Empty<string>();

    // ─────────────────────────────────────────────────────────────────────
    public static ApiSettings LoadAndValidate(IConfiguration cfg)
    {
        var debug = string.Equals(
            cfg["DEBUG"] ?? cfg["Debug"],
            "true",
            StringComparison.OrdinalIgnoreCase);

        var catalogConn  = Require(cfg, "ConnectionStrings:CatalogConnection");
        var identityConn = Require(cfg, "ConnectionStrings:IdentityConnection");
        var jwtSecret    = Require(cfg, "JWT_SECRET_KEY");
        var redisConn    = Require(cfg, "ConnectionStrings:Redis");

        // JWT algorithm allowlist
        var algo = cfg["JWT_ALGORITHM"] ?? cfg["JwtAlgorithm"] ?? "HS256";
        if (string.Equals(algo, "none", StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException(
                "JWT_ALGORITHM 'none' is not permitted — it disables signature verification.");
        if (!AllowedJwtAlgorithms.Contains(algo))
            throw new InvalidOperationException(
                $"JWT_ALGORITHM '{algo}' is not in the allowlist " +
                $"{{HS256, HS384, HS512}}. Update JWT_ALGORITHM to a supported value.");

        // Redis TLS enforcement in production
        if (!debug && !redisConn.StartsWith("rediss://", StringComparison.OrdinalIgnoreCase)
                   && !redisConn.Contains(",ssl=True", StringComparison.OrdinalIgnoreCase)
                   && !redisConn.Contains(",ssl=true", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(
                "ConnectionStrings:Redis MUST use TLS (rediss:// or ,ssl=True) " +
                "when DEBUG is not 'true'.");
        }

        // CORS
        var corsRaw     = cfg["CORS_ORIGINS"] ?? cfg["CorsOrigins"] ?? string.Empty;
        var corsOrigins = ParseList(corsRaw);
        if (!debug)
        {
            if (corsOrigins.Count == 0)
                throw new InvalidOperationException(
                    "CORS_ORIGINS must not be empty in production.");
            if (corsOrigins.Contains("*"))
                throw new InvalidOperationException(
                    "CORS_ORIGINS must not contain '*' in production.");
        }

        // AllowedHosts
        var allowedHostsRaw = cfg["ALLOWED_HOSTS"] ?? cfg["AllowedHosts"] ?? string.Empty;
        var allowedHosts    = ParseList(allowedHostsRaw);
        if (!debug && allowedHosts.Count == 0)
            throw new InvalidOperationException(
                "ALLOWED_HOSTS must not be empty in production.");

        if (!int.TryParse(cfg["PAGE_SIZE"] ?? cfg["PageSize"] ?? "10", out var pageSize)
            || pageSize < 1 || pageSize > 250)
            throw new InvalidOperationException(
                "PAGE_SIZE must be an integer between 1 and 250.");

        return new ApiSettings
        {
            CatalogConnectionString  = catalogConn,
            IdentityConnectionString = identityConn,
            JwtSecretKey             = jwtSecret,
            JwtAlgorithm             = algo,
            JwtIssuer                = cfg["JWT_ISSUER"]   ?? cfg["JwtIssuer"]   ?? string.Empty,
            JwtAudience              = cfg["JWT_AUDIENCE"] ?? cfg["JwtAudience"] ?? string.Empty,
            RedisConnectionString    = redisConn,
            UseAzureKeyVault         = !debug,
            Debug                    = debug,
            LogLevel                 = cfg["LOG_LEVEL"] ?? cfg["LogLevel"] ?? "Information",
            PageSize                 = pageSize,
            CorsOrigins              = corsOrigins,
            AllowedHosts             = allowedHosts,
        };
    }

    private static string Require(IConfiguration cfg, string key)
    {
        var value = cfg[key];
        if (string.IsNullOrWhiteSpace(value))
            throw new InvalidOperationException(
                $"Required configuration key '{key}' is missing or empty. " +
                $"Set it via environment variable or Azure Key Vault.");
        return value;
    }

    private static IReadOnlyList<string> ParseList(string raw)
    {
        if (string.IsNullOrWhiteSpace(raw))
            return Array.Empty<string>();
        var items = new List<string>();
        foreach (var part in raw.Split(',', ';', StringSplitOptions.RemoveEmptyEntries))
        {
            var trimmed = part.Trim();
            if (!string.IsNullOrEmpty(trimmed)) items.Add(trimmed);
        }
        return items;
    }
}
