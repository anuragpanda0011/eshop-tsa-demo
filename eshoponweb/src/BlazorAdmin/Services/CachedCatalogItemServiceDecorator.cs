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
/// Decorates <see cref="CatalogItemService"/> with a browser local-storage cache.
/// Cache entries expire after 1 minute and are invalidated immediately on any
/// write operation (create / edit / delete).
/// </summary>
public class CachedCatalogItemServiceDecorator : ICatalogItemService
{
    private const string CacheKey = "items";
    private static readonly TimeSpan CacheDuration = TimeSpan.FromMinutes(1);

    private readonly ILocalStorageService _localStorageService;
    private readonly CatalogItemService _catalogItemService;
    private readonly ILogger<CachedCatalogItemServiceDecorator> _logger;

    public CachedCatalogItemServiceDecorator(
        ILocalStorageService localStorageService,
        CatalogItemService catalogItemService,
        ILogger<CachedCatalogItemServiceDecorator> logger)
    {
        _localStorageService = localStorageService;
        _catalogItemService  = catalogItemService;
        _logger              = logger;
    }

    public async Task<List<CatalogItem>> ListPaged(int pageSize)
    {
        // Paged results bypass the flat-list cache to avoid stale pagination.
        return await _catalogItemService.ListPaged(pageSize);
    }

    public async Task<List<CatalogItem>> List()
    {
        var cacheEntry = await _localStorageService
            .GetItemAsync<CacheEntry<List<CatalogItem>>>(CacheKey);

        if (cacheEntry != null)
        {
            if (cacheEntry.DateCreated.Add(CacheDuration) > DateTime.UtcNow)
            {
                _logger.LogInformation(
                    "{{\"event\":\"CacheHit\",\"key\":\"{Key}\"}}", CacheKey);
                return cacheEntry.Value;
            }

            _logger.LogInformation(
                "{{\"event\":\"CacheExpired\",\"key\":\"{Key}\"}}", CacheKey);
            await _localStorageService.RemoveItemAsync(CacheKey);
        }

        return await FetchAndCacheAsync();
    }

    public async Task<CatalogItem> GetById(int id)
    {
        var all = await List();
        return all.FirstOrDefault(x => x.Id == id)!;
    }

    public async Task<CatalogItem> Create(CreateCatalogItemRequest catalogItem)
    {
        var result = await _catalogItemService.Create(catalogItem);
        await InvalidateAndRefreshAsync();
        return result;
    }

    public async Task<CatalogItem> Edit(CatalogItem catalogItem)
    {
        var result = await _catalogItemService.Edit(catalogItem);
        await InvalidateAndRefreshAsync();
        return result;
    }

    public async Task<string> Delete(int id)
    {
        var result = await _catalogItemService.Delete(id);
        await InvalidateAndRefreshAsync();
        return result;
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private async Task<List<CatalogItem>> FetchAndCacheAsync()
    {
        _logger.LogInformation(
            "{{\"event\":\"CacheMiss\",\"key\":\"{Key}\",\"message\":\"Fetching from API\"}}", CacheKey);

        var items = await _catalogItemService.List();
        var entry = new CacheEntry<List<CatalogItem>>(items);
        await _localStorageService.SetItemAsync(CacheKey, entry);
        return items;
    }

    private async Task InvalidateAndRefreshAsync()
    {
        await _localStorageService.RemoveItemAsync(CacheKey);
        await FetchAndCacheAsync();
    }
}
