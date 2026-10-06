using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.Infrastructure.Data.Queries;

public class BasketQueryService : IBasketQueryService
{
    // Cache TTL for basket item counts — short-lived so UI stays reasonably fresh.
    private const int CacheTtlSeconds = 30;

    private readonly CatalogContext _dbContext;
    private readonly IDistributedCache _cache;
    private readonly ILogger<BasketQueryService> _logger;

    public BasketQueryService(
        CatalogContext dbContext,
        IDistributedCache cache,
        ILogger<BasketQueryService> logger)
    {
        _dbContext = dbContext;
        _cache = cache;
        _logger = logger;
    }

    /// <summary>
    /// Returns the total number of items in a user's basket.
    /// The result is cached in Redis for <see cref="CacheTtlSeconds"/> seconds.
    /// The cache key is derived from an SHA-256 hash of the username so that
    /// raw user-supplied strings are never written verbatim into Redis.
    /// </summary>
    public async Task<int> CountTotalBasketItems(string username)
    {
        var cacheKey = BuildCacheKey(username);

        // Try cache first.
        try
        {
            var cached = await _cache.GetStringAsync(cacheKey);
            if (cached is not null && int.TryParse(cached, out var cachedCount))
            {
                _logger.LogInformation(
                    "BasketQueryService cache hit for key {CacheKey}",
                    cacheKey);
                return cachedCount;
            }
        }
        catch (System.Exception ex)
        {
            // Redis unavailable — fall through to DB.
            _logger.LogWarning(ex,
                "BasketQueryService: Redis read failed for key {CacheKey}; falling back to database",
                cacheKey);
        }

        // Query the database using EF (parameterized — EF never string-concatenates SQL).
        var totalItems = await _dbContext.Baskets
            .Where(basket => basket.BuyerId == username)
            .SelectMany(item => item.Items)
            .SumAsync(sum => sum.Quantity);

        _logger.LogInformation(
            "BasketQueryService cache miss — queried database, total={Total} for key {CacheKey}",
            totalItems, cacheKey);

        // Populate cache best-effort.
        try
        {
            var options = new DistributedCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = System.TimeSpan.FromSeconds(CacheTtlSeconds)
            };
            await _cache.SetStringAsync(cacheKey, totalItems.ToString(), options);
        }
        catch (System.Exception ex)
        {
            _logger.LogWarning(ex,
                "BasketQueryService: Redis write failed for key {CacheKey}",
                cacheKey);
        }

        return totalItems;
    }

    // ---------------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------------

    /// <summary>
    /// Derives a fixed-length, opaque Redis key from a user-supplied username
    /// using SHA-256 so that raw user strings are never used as cache keys.
    /// </summary>
    private static string BuildCacheKey(string username)
    {
        var hashBytes = SHA256.HashData(Encoding.UTF8.GetBytes(username));
        var hash = Convert.ToHexString(hashBytes).ToLowerInvariant();
        return $"basket:count:{hash}";
    }
}
