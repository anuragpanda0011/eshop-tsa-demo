using System;
using System.Security.Cryptography;
using System.Text;

namespace Microsoft.eShopWeb.Web.Extensions;

public static class CacheHelpers
{
    public static readonly TimeSpan DefaultCacheDuration = TimeSpan.FromSeconds(30);
    public static readonly TimeSpan BrandsCacheDuration = TimeSpan.FromMinutes(10);
    public static readonly TimeSpan TypesCacheDuration = TimeSpan.FromMinutes(10);

    private static readonly string _itemsKeyTemplate = "items-{0}-{1}-{2}-{3}";

    /// <summary>
    /// Generates a catalog-item cache key and hashes it so that
    /// user-supplied integer parameters cannot be used to poison Redis keys.
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
    /// Returns a SHA-256 hex digest of the supplied raw key.
    /// User-supplied strings must be passed through this method before
    /// being used as Redis cache keys.
    /// </summary>
    public static string HashKey(string rawKey)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(rawKey));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }
}
