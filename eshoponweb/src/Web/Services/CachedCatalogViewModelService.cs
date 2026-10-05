using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.eShopWeb.Web.Extensions;
using Microsoft.eShopWeb.Web.ViewModels;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.Web.Services;

public class CachedCatalogViewModelService : ICatalogViewModelService
{
    private readonly IDistributedCache _cache;
    private readonly CatalogViewModelService _catalogViewModelService;
    private readonly ILogger<CachedCatalogViewModelService> _logger;

    // Keep the same sliding window as the previous in-memory implementation.
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
        var key = HashCacheKey(CacheHelpers.GenerateBrandsCacheKey());
        return await GetOrCreateAsync(
            key,
            () => _catalogViewModelService.GetBrands(),
            new List<SelectListItem>());
    }

    public async Task<CatalogIndexViewModel> GetCatalogItems(
        int pageIndex, int itemsPage, int? brandId, int? typeId)
    {
        var rawKey = CacheHelpers.GenerateCatalogItemCacheKey(
            pageIndex, Constants.ITEMS_PER_PAGE, brandId, typeId);
        var key = HashCacheKey(rawKey);

        return await GetOrCreateAsync(
            key,
            () => _catalogViewModelService.GetCatalogItems(pageIndex, itemsPage, brandId, typeId),
            new CatalogIndexViewModel());
    }

    public async Task<IEnumerable<SelectListItem>> GetTypes()
    {
        var key = HashCacheKey(CacheHelpers.GenerateTypesCacheKey());
        return await GetOrCreateAsync(
            key,
            () => _catalogViewModelService.GetTypes(),
            new List<SelectListItem>());
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    /// <summary>
    /// Hash user-supplied or composite strings before using them as Redis
    /// cache keys to avoid key injection and length issues.
    /// </summary>
    private static string HashCacheKey(string rawKey)
    {
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(rawKey));
        return $"catalog:{Convert.ToHexString(hash).ToLowerInvariant()}";
    }

    private async Task<T> GetOrCreateAsync<T>(
        string cacheKey,
        Func<Task<T>> factory,
        T defaultValue)
    {
        try
        {
            var cached = await _cache.GetStringAsync(cacheKey);
            if (cached != null)
            {
                var deserialized = JsonSerializer.Deserialize<T>(cached);
                if (deserialized != null)
                {
                    _logger.LogInformation(
                        "{\"event\":\"CatalogCacheHit\",\"key\":\"{CacheKey}\"}",
                        cacheKey);
                    return deserialized;
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex,
                "{\"event\":\"CatalogCacheReadError\",\"key\":\"{CacheKey}\"}",
                cacheKey);
        }

        var result = await factory();

        try
        {
            var json = JsonSerializer.Serialize(result);
            await _cache.SetStringAsync(cacheKey, json, new DistributedCacheEntryOptions
            {
                SlidingExpiration = DefaultCacheDuration
            });
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex,
                "{\"event\":\"CatalogCacheWriteError\",\"key\":\"{CacheKey}\"}",
                cacheKey);
        }

        return result ?? defaultValue;
    }
}
