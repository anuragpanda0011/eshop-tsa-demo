using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Blazored.LocalStorage;
using BlazorShared.Interfaces;
using BlazorShared.Models;
using Microsoft.Extensions.Logging;

namespace BlazorAdmin.Services;

/// <summary>
/// Decorates <see cref="CatalogLookupDataService{TLookupData,TResponse}"/>
/// with a browser local-storage cache (TTL = 1 minute).
/// </summary>
public class CachedCatalogLookupDataServiceDecorator<TLookupData, TReponse>
    : ICatalogLookupDataService<TLookupData>
    where TLookupData : LookupData
    where TReponse : ILookupDataResponse<TLookupData>
{
    private static readonly TimeSpan CacheTtl = TimeSpan.FromMinutes(1);

    private readonly ILocalStorageService _localStorageService;
    private readonly CatalogLookupDataService<TLookupData, TReponse> _catalogTypeService;
    private readonly ILogger<CachedCatalogLookupDataServiceDecorator<TLookupData, TReponse>> _logger;

    public CachedCatalogLookupDataServiceDecorator(
        ILocalStorageService localStorageService,
        CatalogLookupDataService<TLookupData, TReponse> catalogTypeService,
        ILogger<CachedCatalogLookupDataServiceDecorator<TLookupData, TReponse>> logger)
    {
        _localStorageService = localStorageService;
        _catalogTypeService = catalogTypeService;
        _logger = logger;
    }

    public async Task<List<TLookupData>> List()
    {
        string key = typeof(TLookupData).Name;

        var cacheEntry = await _localStorageService
            .GetItemAsync<CacheEntry<List<TLookupData>>>(key);

        if (cacheEntry != null)
        {
            if (cacheEntry.DateCreated.Add(CacheTtl) > DateTime.UtcNow)
            {
                _logger.LogInformation(
                    "{{\"event\":\"cache_hit\",\"key\":\"{Key}\",\"source\":\"local_storage\"}}",
                    key);
                return cacheEntry.Value;
            }

            _logger.LogInformation(
                "{{\"event\":\"cache_expired\",\"key\":\"{Key}\",\"source\":\"local_storage\"}}",
                key);
            await _localStorageService.RemoveItemAsync(key);
        }

        var types = await _catalogTypeService.List();
        var entry = new CacheEntry<List<TLookupData>>(types);
        await _localStorageService.SetItemAsync(key, entry);
        return types;
    }
}
