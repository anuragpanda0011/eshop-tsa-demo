using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.eShopWeb.Web.Extensions;
using Microsoft.eShopWeb.Web.ViewModels;
using Microsoft.Extensions.Caching.Distributed;

namespace Microsoft.eShopWeb.Web.Services;

/// <summary>
/// Redis-backed distributed cache wrapper around CatalogViewModelService.
/// Cache keys are SHA-256 hashed to avoid injection via user-supplied inputs.
/// </summary>
public class CachedCatalogViewModelService : ICatalogViewModelService
{
    private readonly IDistributedCache _cache;
    private readonly CatalogViewModelService _catalogViewModelService;
    private readonly ILogger<CachedCatalogViewModelService> _logger;

    // TTL mirrors the previous sliding expiration used with IMemoryCache
    private static readonly TimeSpan DefaultCacheDuration = CacheHelpers.DefaultCacheDuration;

    public CachedCatalogViewModelService(
        IDistributedCache cache,
        CatalogViewModelService catalogViewModelService,
        ILogger<CachedCatalogViewModelService> logger)
    {
        _cache = cache;
        _catalogViewModelService = catalogViewModelService;
        _logger = logger;
    }

    public async Task<IEnumerable<SelectListItem>> GetBrands()
    {
        var cacheKey = HashKey(CacheHelpers.GenerateBrandsCacheKey());
        return await GetOrSetAsync(
            cacheKey,
            () => _catalogViewModelService.GetBrands(),
            () => new List<SelectListItem>());
    }

    public async Task<CatalogIndexViewModel> GetCatalogItems(
        int pageIndex, int itemsPage, int? brandId, int? typeId)
    {
        var rawKey = CacheHelpers.GenerateCatalogItemCacheKey(
            pageIndex, Constants.ITEMS_PER_PAGE, brandId, typeId);
        var cacheKey = HashKey(rawKey);

        return await GetOrSetAsync(
            cacheKey,
            () => _catalogViewModelService.GetCatalogItems(pageIndex, itemsPage, brandId, typeId),
            () => new CatalogIndexViewModel());
    }

    public async Task<IEnumerable<SelectListItem>> GetTypes()
    {
        var cacheKey = HashKey(CacheHelpers.GenerateTypesCacheKey());
        return await GetOrSetAsync(
            cacheKey,
            () => _catalogViewModelService.GetTypes(),
            () => new List<SelectListItem>());
    }

    // -------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------

    /// <summary>
    /// SHA-256 hash of a cache key to prevent user-controlled key injection.
    /// </summary>
    private static string HashKey(string rawKey)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(rawKey));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }

    private async Task<T> GetOrSetAsync<T>(
        string cacheKey,
        Func<Task<T>> factory,
        Func<T> defaultValue)
    {
        try
        {
            var cached = await _cache.GetStringAsync(cacheKey);
            if (cached != null)
            {
                _logger.LogDebug("Cache HIT for key={CacheKey}", cacheKey);
                var deserialized = JsonSerializer.Deserialize<T>(cached);
                return deserialized ?? defaultValue();
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex,
                "Redis cache GET failed for key={CacheKey}; falling through to source",
                cacheKey);
        }

        _logger.LogDebug("Cache MISS for key={CacheKey}", cacheKey);
        var result = await factory();

        try
        {
            var serialized = JsonSerializer.Serialize(result);
            var options = new DistributedCacheEntryOptions
            {
                SlidingExpiration = DefaultCacheDuration
            };
            await _cache.SetStringAsync(cacheKey, serialized, options);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex,
                "Redis cache SET failed for key={CacheKey}; result still returned",
                cacheKey);
        }

        return result;
    }
}
