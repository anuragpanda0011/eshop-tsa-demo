using System;
using System.Collections.Generic;
using Microsoft.Extensions.Configuration;

namespace Microsoft.eShopOnWeb.Web.Configuration;

/// <summary>
/// Strongly-typed, validated settings for the Web (storefront) process.
/// All values are read from environment variables / IConfiguration.
/// Secrets are read from Azure Key Vault via the host builder — they must
/// NEVER be given default values here.
/// </summary>
public sealed class AppSettings
{
    // ── Secrets (Key Vault / env — no defaults) ───────────────────────────
    public string CatalogConnectionString { get; init; }
    public string IdentityConnectionString { get; init; }

    // ── Redis ─────────────────────────────────────────────────────────────
    public string RedisConnectionString { get; init; }

    // ── Feature flags ─────────────────────────────────────────────────────
    public bool UseAzureKeyVault { get; init; } = true;
    public bool Debug { get; init; } = false;

    // ── Observability ─────────────────────────────────────────────────────
    public string LogLevel { get; init; } = "Information";

    // ── Pagination ────────────────────────────────────────────────────────
    public int PageSize { get; init; } = 10;

    // ── CORS ──────────────────────────────────────────────────────────────
    public IReadOnlyList<string> CorsOrigins { get; init; } = Array.Empty<string>();

    // ── Host ──────────────────────────────────────────────────────────────
    public IReadOnlyList<string> AllowedHosts { get; init; } = Array.Empty<string>();

    // ── Data Protection ───────────────────────────────────────────────────
    public string DataProtectionBlobContainer { get; init; } = "dataprotection";
    public string DataProtectionKeyIdentifier { get; init; } = string.Empty;

    // ─────────────────────────────────────────────────────────────────────
    // Factory — reads from IConfiguration and validates at startup.
    // ─────────────────────────────────────────────────────────────────────
    public static AppSettings LoadAndValidate(IConfiguration cfg)
    {
        var debug = string.Equals(
            cfg["DEBUG"] ?? cfg["Debug"],
            "true",
            StringComparison.OrdinalIgnoreCase);

        var catalogConn   = Require(cfg, "ConnectionStrings:CatalogConnection");
        var identityConn  = Require(cfg, "ConnectionStrings:IdentityConnection");
        var redisConn     = Require(cfg, "ConnectionStrings:Redis");

        // Redis must be TLS in production
        if (!debug && !redisConn.StartsWith("rediss://", StringComparison.OrdinalIgnoreCase)
                   && !redisConn.Contains(",ssl=True", StringComparison.OrdinalIgnoreCase)
                   && !redisConn.Contains(",ssl=true", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(
                "ConnectionStrings:Redis MUST use TLS (rediss:// or ,ssl=True) " +
                "when DEBUG is not 'true'. Set DEBUG=true only for local development.");
        }

        // CORS must not be '*' or empty in production
        var corsRaw = cfg["CORS_ORIGINS"] ?? cfg["CorsOrigins"] ?? string.Empty;
        var corsOrigins = ParseList(corsRaw);
        if (!debug)
        {
            if (corsOrigins.Count == 0)
                throw new InvalidOperationException(
                    "CORS_ORIGINS must not be empty in production. " +
                    "Set it to the explicit list of allowed origins.");
            if (corsOrigins.Contains("*"))
                throw new InvalidOperationException(
                    "CORS_ORIGINS must not contain '*' in production.");
        }

        // AllowedHosts
        var allowedHostsRaw = cfg["ALLOWED_HOSTS"] ?? cfg["AllowedHosts"] ?? string.Empty;
        var allowedHosts = ParseList(allowedHostsRaw);
        if (!debug && allowedHosts.Count == 0)
            throw new InvalidOperationException(
                "ALLOWED_HOSTS must not be empty in production.");

        if (!int.TryParse(cfg["PAGE_SIZE"] ?? cfg["PageSize"] ?? "10", out var pageSize)
            || pageSize < 1 || pageSize > 250)
            throw new InvalidOperationException(
                "PAGE_SIZE must be an integer between 1 and 250.");

        return new AppSettings
        {
            CatalogConnectionString  = catalogConn,
            IdentityConnectionString = identityConn,
            RedisConnectionString    = redisConn,
            UseAzureKeyVault         = !debug,
            Debug                    = debug,
            LogLevel                 = cfg["LOG_LEVEL"] ?? cfg["LogLevel"] ?? "Information",
            PageSize                 = pageSize,
            CorsOrigins              = corsOrigins,
            AllowedHosts             = allowedHosts,
            DataProtectionBlobContainer =
                cfg["DATA_PROTECTION_BLOB_CONTAINER"] ?? "dataprotection",
            DataProtectionKeyIdentifier =
                cfg["DATA_PROTECTION_KEY_IDENTIFIER"] ?? string.Empty,
        };
    }

    // ── Helpers ───────────────────────────────────────────────────────────

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
            if (!string.IsNullOrEmpty(trimmed))
                items.Add(trimmed);
        }
        return items;
    }
}
