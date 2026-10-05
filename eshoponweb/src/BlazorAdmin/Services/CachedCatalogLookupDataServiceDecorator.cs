using System;
using System.Collections.Generic;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Blazored.LocalStorage;
using BlazorShared.Interfaces;
using BlazorShared.Models;
using Microsoft.Extensions.Logging;

namespace BlazorAdmin.Services;

public class CachedCatalogLookupDataServiceDecorator<TLookupData, TReponse>
    : ICatalogLookupDataService<TLookupData>
    where TLookupData : LookupData
    where TReponse : ILookupDataResponse<TLookupData>
{
    private readonly ILocalStorageService _localStorageService;
    private readonly CatalogLookupDataService<TLookupData, TReponse> _catalogTypeService;
    private readonly ILogger<CachedCatalogLookupDataServiceDecorator<TLookupData, TReponse>> _logger;

    private static readonly TimeSpan CacheTtl = TimeSpan.FromMinutes(1);

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
        string rawKey = typeof(TLookupData).Name;
        string key = HashKey(rawKey);

        try
        {
            var cacheEntry = await _localStorageService.GetItemAsync<CacheEntry<List<TLookupData>>>(key);
            if (cacheEntry != null)
            {
                _logger.LogInformation(
                    "{\"event\":\"cache_lookup\",\"type\":\"{TypeName}\",\"status\":\"hit\"}",
                    rawKey);

                if (cacheEntry.DateCreated.Add(CacheTtl) > DateTime.UtcNow)
                {
                    return cacheEntry.Value;
                }

                _logger.LogInformation(
                    "{\"event\":\"cache_expired\",\"type\":\"{TypeName}\"}",
                    rawKey);
                await _localStorageService.RemoveItemAsync(key);
            }
            else
            {
                _logger.LogInformation(
                    "{\"event\":\"cache_lookup\",\"type\":\"{TypeName}\",\"status\":\"miss\"}",
                    rawKey);
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex,
                "{\"event\":\"cache_read_error\",\"type\":\"{TypeName}\"}",
                rawKey);
        }

        var items = await _catalogTypeService.List();

        try
        {
            var entry = new CacheEntry<List<TLookupData>>(items);
            await _localStorageService.SetItemAsync(key, entry);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex,
                "{\"event\":\"cache_write_error\",\"type\":\"{TypeName}\"}",
                rawKey);
        }

        return items;
    }

    /// <summary>
    /// SHA-256 hash of the raw cache key so user-supplied or type-derived strings
    /// are never used verbatim as storage keys.
    /// </summary>
    private static string HashKey(string rawKey)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(rawKey));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }
}
