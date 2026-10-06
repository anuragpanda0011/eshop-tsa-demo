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
    private readonly IServiceBusPublisher _serviceBusPublisher;
    private readonly IEmailSender _emailSender;
    private readonly IAppLogger<OrderService> _logger;

    public OrderService(
        IRepository<Basket> basketRepository,
        IRepository<CatalogItem> itemRepository,
        IRepository<Order> orderRepository,
        IUriComposer uriComposer,
        IServiceBusPublisher serviceBusPublisher,
        IEmailSender emailSender,
        IAppLogger<OrderService> logger)
    {
        _orderRepository = orderRepository;
        _uriComposer = uriComposer;
        _basketRepository = basketRepository;
        _itemRepository = itemRepository;
        _serviceBusPublisher = serviceBusPublisher;
        _emailSender = emailSender;
        _logger = logger;
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
            var orderItem = new OrderItem(itemOrdered, basketItem.UnitPrice, basketItem.Quantity);
            return orderItem;
        }).ToList();

        var order = new Order(basket.BuyerId, shippingAddress, items);

        await _orderRepository.AddAsync(order);

        _logger.LogInformation(
            "Order {OrderId} created for buyer {BuyerId} with {ItemCount} item(s). Total: {Total}.",
            order.Id, order.BuyerId, order.OrderItems.Count, order.Total());

        // Publish domain event — best-effort
        await _serviceBusPublisher.PublishAsync("order.created", new
        {
            OrderId = order.Id,
            BuyerId = order.BuyerId,
            OrderDate = order.OrderDate,
            Total = order.Total(),
            ItemCount = order.OrderItems.Count,
            ShipToAddress = new
            {
                shippingAddress.Street,
                shippingAddress.City,
                shippingAddress.State,
                shippingAddress.Country,
                shippingAddress.ZipCode
            }
        });

        // Send order confirmation email — best-effort
        try
        {
            await _emailSender.SendEmailAsync(
                basket.BuyerId,
                $"Order Confirmation #{order.Id}",
                BuildOrderConfirmationHtml(order));
        }
        catch (System.Exception ex)
        {
            _logger.LogWarning(
                "Failed to send order confirmation email for order {OrderId}: {Error}",
                order.Id, ex.Message);
        }
    }

    private static string BuildOrderConfirmationHtml(Order order)
    {
        var sb = new System.Text.StringBuilder();
        sb.AppendLine($"<h2>Thank you for your order #{order.Id}!</h2>");
        sb.AppendLine($"<p>Order date: {order.OrderDate:f}</p>");
        sb.AppendLine("<h3>Items:</h3><ul>");
        foreach (var item in order.OrderItems)
        {
            sb.AppendLine(
                $"<li>{System.Net.WebUtility.HtmlEncode(item.ItemOrdered.ProductName)} " +
                $"&times; {item.Units} @ {item.UnitPrice:C}</li>");
        }
        sb.AppendLine("</ul>");
        sb.AppendLine($"<p><strong>Total: {order.Total():C}</strong></p>");
        return sb.ToString();
    }
}
