using System.Security.Cryptography;
using System.Text;
using Microsoft.eShopWeb.ApplicationCore.Entities;
using Microsoft.eShopWeb.ApplicationCore.Entities.BasketAggregate;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.eShopWeb.ApplicationCore.Specifications;
using Microsoft.eShopWeb.Web.Interfaces;
using Microsoft.eShopWeb.Web.Pages.Basket;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Logging;
using System.Text.Json;

namespace Microsoft.eShopWeb.Web.Services;

public class BasketViewModelService : IBasketViewModelService
{
    private static readonly TimeSpan BasketCacheTtl = TimeSpan.FromMinutes(5);

    private readonly IRepository<Basket> _basketRepository;
    private readonly IUriComposer _uriComposer;
    private readonly IBasketQueryService _basketQueryService;
    private readonly IRepository<CatalogItem> _itemRepository;
    private readonly IDistributedCache _cache;
    private readonly ILogger<BasketViewModelService> _logger;

    public BasketViewModelService(
        IRepository<Basket> basketRepository,
        IRepository<CatalogItem> itemRepository,
        IUriComposer uriComposer,
        IBasketQueryService basketQueryService,
        IDistributedCache cache,
        ILogger<BasketViewModelService> logger)
    {
        _basketRepository = basketRepository;
        _uriComposer = uriComposer;
        _basketQueryService = basketQueryService;
        _itemRepository = itemRepository;
        _cache = cache;
        _logger = logger;
    }

    public async Task<BasketViewModel> GetOrCreateBasketForUser(string userName)
    {
        var cacheKey = BuildUserCacheKey(userName);

        var cached = await _cache.GetStringAsync(cacheKey);
        if (cached != null)
        {
            try
            {
                var cachedVm = JsonSerializer.Deserialize<BasketViewModel>(cached);
                if (cachedVm != null)
                {
                    _logger.LogInformation(
                        "{{\"event\":\"BasketCacheHit\",\"user\":\"{HashedUser}\"}}",
                        cacheKey);
                    return cachedVm;
                }
            }
            catch (JsonException ex)
            {
                _logger.LogWarning(ex,
                    "{{\"event\":\"BasketCacheDeserializeError\",\"cacheKey\":\"{CacheKey}\"}}",
                    cacheKey);
            }
        }

        var basketSpec = new BasketWithItemsSpecification(userName);
        var basket = await _basketRepository.FirstOrDefaultAsync(basketSpec);

        BasketViewModel viewModel;
        if (basket == null)
        {
            viewModel = await CreateBasketForUser(userName);
        }
        else
        {
            viewModel = await Map(basket);
        }

        await SetBasketCacheAsync(cacheKey, viewModel);
        return viewModel;
    }

    private async Task<BasketViewModel> CreateBasketForUser(string userId)
    {
        var basket = new Basket(userId);
        await _basketRepository.AddAsync(basket);

        _logger.LogInformation(
            "{{\"event\":\"BasketCreated\",\"basketId\":{BasketId}}}",
            basket.Id);

        return new BasketViewModel
        {
            BuyerId = basket.BuyerId,
            Id = basket.Id
        };
    }

    private async Task<List<BasketItemViewModel>> GetBasketItems(IReadOnlyCollection<BasketItem> basketItems)
    {
        var catalogItemsSpecification = new CatalogItemsSpecification(
            basketItems.Select(b => b.CatalogItemId).ToArray());
        var catalogItems = await _itemRepository.ListAsync(catalogItemsSpecification);

        var items = basketItems.Select(basketItem =>
        {
            var catalogItem = catalogItems.First(c => c.Id == basketItem.CatalogItemId);

            return new BasketItemViewModel
            {
                Id = basketItem.Id,
                UnitPrice = basketItem.UnitPrice,
                Quantity = basketItem.Quantity,
                CatalogItemId = basketItem.CatalogItemId,
                PictureUrl = _uriComposer.ComposePicUri(catalogItem.PictureUri),
                ProductName = catalogItem.Name
            };
        }).ToList();

        return items;
    }

    public async Task<BasketViewModel> Map(Basket basket)
    {
        return new BasketViewModel
        {
            BuyerId = basket.BuyerId,
            Id = basket.Id,
            Items = await GetBasketItems(basket.Items)
        };
    }

    public async Task<int> CountTotalBasketItems(string username)
    {
        return await _basketQueryService.CountTotalBasketItems(username);
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    /// <summary>
    /// Hash the username before using it as a Redis cache key so that
    /// user-supplied strings are never directly embedded in key names.
    /// </summary>
    private static string BuildUserCacheKey(string username)
    {
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(username));
        return $"basket:user:{Convert.ToHexString(hash).ToLowerInvariant()}";
    }

    private async Task SetBasketCacheAsync(string cacheKey, BasketViewModel vm)
    {
        try
        {
            var json = JsonSerializer.Serialize(vm);
            await _cache.SetStringAsync(cacheKey, json, new DistributedCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = BasketCacheTtl
            });
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex,
                "{{\"event\":\"BasketCacheSetError\",\"cacheKey\":\"{CacheKey}\"}}",
                cacheKey);
        }
    }

    /// <summary>Invalidate the basket cache for a user after a write.</summary>
    public async Task InvalidateBasketCacheAsync(string username)
    {
        var cacheKey = BuildUserCacheKey(username);
        try
        {
            await _cache.RemoveAsync(cacheKey);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex,
                "{{\"event\":\"BasketCacheInvalidateError\",\"cacheKey\":\"{CacheKey}\"}}",
                cacheKey);
        }
    }
}
