using System;
using System.Linq;
using System.Threading.Tasks;
using Ardalis.GuardClauses;
using Microsoft.eShopWeb.ApplicationCore.Entities;
using Microsoft.eShopWeb.ApplicationCore.Entities.BasketAggregate;
using Microsoft.eShopWeb.ApplicationCore.Entities.OrderAggregate;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.eShopWeb.ApplicationCore.Specifications;

namespace Microsoft.eShopWeb.ApplicationCore.Services;

public class OrderService : IOrderService
{
    private readonly IRepository<Order> _orderRepository;
    private readonly IUriComposer _uriComposer;
    private readonly IRepository<Basket> _basketRepository;
    private readonly IRepository<CatalogItem> _itemRepository;
    private readonly IServiceBusPublisher _publisher;
    private readonly IEmailSender _emailSender;

    public OrderService(
        IRepository<Basket> basketRepository,
        IRepository<CatalogItem> itemRepository,
        IRepository<Order> orderRepository,
        IUriComposer uriComposer,
        IServiceBusPublisher publisher,
        IEmailSender emailSender)
    {
        _orderRepository  = orderRepository;
        _uriComposer      = uriComposer;
        _basketRepository = basketRepository;
        _itemRepository   = itemRepository;
        _publisher        = publisher;
        _emailSender      = emailSender;
    }

    public async Task CreateOrderAsync(int basketId, Address shippingAddress)
    {
        var basketSpec = new BasketWithItemsSpecification(basketId);
        var basket = await _basketRepository.FirstOrDefaultAsync(basketSpec);

        Guard.Against.Null(basket, nameof(basket));
        Guard.Against.EmptyBasketOnCheckout(basket.Items);

        var catalogItemsSpecification = new CatalogItemsSpecification(
            basket.Items.Select(item => item.CatalogItemId).ToArray());
        var catalogItems = await _itemRepository.ListAsync(catalogItemsSpecification);

        var items = basket.Items.Select(basketItem =>
        {
            var catalogItem = catalogItems.First(c => c.Id == basketItem.CatalogItemId);
            var itemOrdered = new CatalogItemOrdered(
                catalogItem.Id,
                catalogItem.Name,
                _uriComposer.ComposePicUri(catalogItem.PictureUri));
            return new OrderItem(itemOrdered, basketItem.UnitPrice, basketItem.Quantity);
        }).ToList();

        var order = new Order(basket.BuyerId, shippingAddress, items);
        await _orderRepository.AddAsync(order);

        // Publish domain event — best-effort
        await _publisher.PublishAsync("OrderCreated", new
        {
            OrderId    = order.Id,
            BuyerId    = order.BuyerId,
            Total      = order.Total(),
            ItemCount  = items.Count,
            OccurredAt = DateTimeOffset.UtcNow
        });

        // Send order confirmation email — best-effort (exceptions are swallowed so the
        // order is not rolled back if the email service is unavailable)
        try
        {
            await _emailSender.SendEmailAsync(
                order.BuyerId,
                $"Order #{order.Id} Confirmation",
                $"Thank you for your order. Your order #{order.Id} has been placed successfully. " +
                $"Total: {order.Total():C}");
        }
        catch
        {
            // Email failure must not abort the order
        }
    }
}
