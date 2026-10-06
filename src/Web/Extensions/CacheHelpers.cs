using System;
using System.Security.Cryptography;
using System.Text;

namespace Microsoft.eShopWeb.Web.Extensions;

public static class CacheHelpers
{
    public static readonly TimeSpan DefaultCacheDuration = TimeSpan.FromSeconds(30);
    private static readonly string _itemsKeyTemplate = "items-{0}-{1}-{2}-{3}";

    /// <summary>
    /// Generates a cache key for catalog items. The raw key is hashed with SHA-256
    /// before use to prevent user-supplied data from being embedded verbatim in Redis keys.
    /// </summary>
    public static string GenerateCatalogItemCacheKey(int pageIndex, int itemsPage, int? brandId, int? typeId)
    {
        var rawKey = string.Format(_itemsKeyTemplate, pageIndex, itemsPage, brandId, typeId);
        return HashKey(rawKey);
    }

    public static string GenerateBrandsCacheKey()
    {
        return HashKey("brands");
    }

    public static string GenerateTypesCacheKey()
    {
        return HashKey("types");
    }

    /// <summary>
    /// SHA-256 hash of the supplied string, returned as a lowercase hex string.
    /// Used to avoid user-controlled data appearing verbatim in cache keys.
    /// </summary>
    private static string HashKey(string rawKey)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(rawKey));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }
}
