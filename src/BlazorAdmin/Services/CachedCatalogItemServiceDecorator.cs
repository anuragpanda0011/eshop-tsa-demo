using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Blazored.LocalStorage;
using BlazorShared.Interfaces;
using BlazorShared.Models;
using Microsoft.Extensions.Logging;

namespace BlazorAdmin.Services;

/// <summary>
/// Decorates <see cref="CatalogItemService"/> with a browser local-storage
/// cache (TTL = 1 minute).  The server-side Redis cache is the authoritative
/// cache for the API tier; this layer only reduces round-trips from the
/// Blazor WASM client.
/// </summary>
public class CachedCatalogItemServiceDecorator : ICatalogItemService
{
    private const string CacheKey = "catalog_items";
    private static readonly TimeSpan CacheTtl = TimeSpan.FromMinutes(1);

    private readonly ILocalStorageService _localStorageService;
    private readonly CatalogItemService _catalogItemService;
    private readonly ILogger<CachedCatalogItemServiceDecorator> _logger;

    public CachedCatalogItemServiceDecorator(
        ILocalStorageService localStorageService,
        CatalogItemService catalogItemService,
        ILogger<CachedCatalogItemServiceDecorator> logger)
    {
        _localStorageService = localStorageService;
        _catalogItemService = catalogItemService;
        _logger = logger;
    }

    public async Task<List<CatalogItem>> ListPaged(int pageSize)
    {
        // Paged results bypass the flat-list cache to avoid mixing page sizes.
        return await _catalogItemService.ListPaged(pageSize);
    }

    public async Task<List<CatalogItem>> List()
    {
        var cached = await TryGetFromCache();
        if (cached != null)
        {
            return cached;
        }

        var items = await _catalogItemService.List();
        await SetCache(items);
        return items;
    }

    public async Task<CatalogItem> GetById(int id)
    {
        return (await List()).FirstOrDefault(x => x.Id == id);
    }

    public async Task<CatalogItem> Create(CreateCatalogItemRequest catalogItem)
    {
        var result = await _catalogItemService.Create(catalogItem);
        await RefreshLocalStorageList();
        return result;
    }

    public async Task<CatalogItem> Edit(CatalogItem catalogItem)
    {
        var result = await _catalogItemService.Edit(catalogItem);
        await RefreshLocalStorageList();
        return result;
    }

    public async Task<string> Delete(int id)
    {
        var result = await _catalogItemService.Delete(id);
        await RefreshLocalStorageList();
        return result;
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    private async Task<List<CatalogItem>> TryGetFromCache()
    {
        var cacheEntry = await _localStorageService
            .GetItemAsync<CacheEntry<List<CatalogItem>>>(CacheKey);

        if (cacheEntry == null)
        {
            return null;
        }

        if (cacheEntry.DateCreated.Add(CacheTtl) > DateTime.UtcNow)
        {
            _logger.LogInformation(
                "{{\"event\":\"cache_hit\",\"key\":\"{Key}\",\"source\":\"local_storage\"}}",
                CacheKey);
            return cacheEntry.Value;
        }

        _logger.LogInformation(
            "{{\"event\":\"cache_expired\",\"key\":\"{Key}\",\"source\":\"local_storage\"}}",
            CacheKey);
        await _localStorageService.RemoveItemAsync(CacheKey);
        return null;
    }

    private async Task SetCache(List<CatalogItem> items)
    {
        var entry = new CacheEntry<List<CatalogItem>>(items);
        await _localStorageService.SetItemAsync(CacheKey, entry);
    }

    private async Task RefreshLocalStorageList()
    {
        await _localStorageService.RemoveItemAsync(CacheKey);
        var items = await _catalogItemService.List();
        await SetCache(items);
    }
}
