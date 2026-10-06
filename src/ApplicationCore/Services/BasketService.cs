using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Ardalis.GuardClauses;
using Ardalis.Result;
using Microsoft.eShopWeb.ApplicationCore.Entities.BasketAggregate;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.eShopWeb.ApplicationCore.Specifications;

namespace Microsoft.eShopWeb.ApplicationCore.Services;

public class BasketService : IBasketService
{
    private readonly IRepository<Basket> _basketRepository;
    private readonly IAppLogger<BasketService> _logger;
    private readonly IServiceBusPublisher _serviceBusPublisher;

    public BasketService(
        IRepository<Basket> basketRepository,
        IAppLogger<BasketService> logger,
        IServiceBusPublisher serviceBusPublisher)
    {
        _basketRepository = basketRepository;
        _logger = logger;
        _serviceBusPublisher = serviceBusPublisher;
    }

    public async Task<Basket> AddItemToBasket(string username, int catalogItemId, decimal price, int quantity = 1)
    {
        var basketSpec = new BasketWithItemsSpecification(username);
        var basket = await _basketRepository.FirstOrDefaultAsync(basketSpec);

        if (basket == null)
        {
            basket = new Basket(username);
            await _basketRepository.AddAsync(basket);
        }

        basket.AddItem(catalogItemId, price, quantity);

        await _basketRepository.UpdateAsync(basket);

        // Publish domain event — best-effort
        await _serviceBusPublisher.PublishAsync("basket.item.added", new
        {
            BasketId = basket.Id,
            BuyerId = username,
            CatalogItemId = catalogItemId,
            Quantity = quantity,
            UnitPrice = price
        });

        return basket;
    }

    public async Task DeleteBasketAsync(int basketId)
    {
        var basket = await _basketRepository.GetByIdAsync(basketId);
        Guard.Against.Null(basket, nameof(basket));
        await _basketRepository.DeleteAsync(basket);

        // Publish domain event — best-effort
        await _serviceBusPublisher.PublishAsync("basket.deleted", new
        {
            BasketId = basketId
        });
    }

    public async Task<Result<Basket>> SetQuantities(int basketId, Dictionary<string, int> quantities)
    {
        var basketSpec = new BasketWithItemsSpecification(basketId);
        var basket = await _basketRepository.FirstOrDefaultAsync(basketSpec);
        if (basket == null) return Result<Basket>.NotFound();

        foreach (var item in basket.Items)
        {
            if (quantities.TryGetValue(item.Id.ToString(), out var quantity))
            {
                _logger.LogInformation(
                    "Updating quantity of item ID:{ItemId} to {Quantity}.",
                    item.Id, quantity);
                item.SetQuantity(quantity);
            }
        }

        basket.RemoveEmptyItems();
        await _basketRepository.UpdateAsync(basket);

        // Publish domain event — best-effort
        await _serviceBusPublisher.PublishAsync("basket.quantities.updated", new
        {
            BasketId = basketId,
            Quantities = quantities
        });

        return basket;
    }

    public async Task TransferBasketAsync(string anonymousId, string userName)
    {
        var anonymousBasketSpec = new BasketWithItemsSpecification(anonymousId);
        var anonymousBasket = await _basketRepository.FirstOrDefaultAsync(anonymousBasketSpec);
        if (anonymousBasket == null) return;

        var userBasketSpec = new BasketWithItemsSpecification(userName);
        var userBasket = await _basketRepository.FirstOrDefaultAsync(userBasketSpec);
        if (userBasket == null)
        {
            userBasket = new Basket(userName);
            await _basketRepository.AddAsync(userBasket);
        }

        foreach (var item in anonymousBasket.Items)
        {
            userBasket.AddItem(item.CatalogItemId, item.UnitPrice, item.Quantity);
        }

        await _basketRepository.UpdateAsync(userBasket);
        await _basketRepository.DeleteAsync(anonymousBasket);

        // Publish domain event — best-effort
        await _serviceBusPublisher.PublishAsync("basket.transferred", new
        {
            AnonymousId = anonymousId,
            UserName = userName,
            TargetBasketId = userBasket.Id
        });
    }
}
