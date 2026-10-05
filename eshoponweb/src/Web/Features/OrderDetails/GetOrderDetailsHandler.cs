using System.Text.Json;
using MediatR;
using Microsoft.eShopWeb.ApplicationCore.Entities.OrderAggregate;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.eShopWeb.ApplicationCore.Specifications;
using Microsoft.eShopWeb.Web.Extensions;
using Microsoft.eShopWeb.Web.ViewModels;
using Microsoft.Extensions.Caching.Distributed;

namespace Microsoft.eShopWeb.Web.Features.OrderDetails;

public class GetOrderDetailsHandler : IRequestHandler<GetOrderDetails, OrderDetailViewModel?>
{
    private readonly IReadRepository<Order> _orderRepository;
    private readonly IDistributedCache _cache;
    private readonly IAppLogger<GetOrderDetailsHandler> _logger;

    public GetOrderDetailsHandler(
        IReadRepository<Order> orderRepository,
        IDistributedCache cache,
        IAppLogger<GetOrderDetailsHandler> logger)
    {
        _orderRepository = orderRepository;
        _cache = cache;
        _logger = logger;
    }

    public async Task<OrderDetailViewModel?> Handle(
        GetOrderDetails request,
        CancellationToken cancellationToken)
    {
        // Hash user-supplied composite key before using as cache key
        var cacheKey = CacheHelpers.HashKey($"order-detail-{request.UserName}-{request.OrderId}");

        var cached = await _cache.GetStringAsync(cacheKey, cancellationToken);
        if (cached != null)
        {
            _logger.LogInformation(
                "Cache hit for order detail '{OrderId}', user '{UserName}'.",
                request.OrderId,
                request.UserName);
            return JsonSerializer.Deserialize<OrderDetailViewModel>(cached);
        }

        var spec = new OrderWithItemsByIdSpec(request.OrderId);
        var order = await _orderRepository.FirstOrDefaultAsync(spec, cancellationToken);

        if (order == null)
        {
            return null;
        }

        var viewModel = new OrderDetailViewModel
        {
            OrderDate = order.OrderDate,
            OrderItems = order.OrderItems.Select(oi => new OrderItemViewModel
            {
                PictureUrl = oi.ItemOrdered.PictureUri,
                ProductId = oi.ItemOrdered.CatalogItemId,
                ProductName = oi.ItemOrdered.ProductName,
                UnitPrice = oi.UnitPrice,
                Units = oi.Units
            }).ToList(),
            OrderNumber = order.Id,
            ShippingAddress = order.ShipToAddress,
            Total = order.Total()
        };

        var serialized = JsonSerializer.Serialize(viewModel);
        var options = new DistributedCacheEntryOptions
        {
            AbsoluteExpirationRelativeToNow = CacheHelpers.DefaultCacheDuration
        };
        await _cache.SetStringAsync(cacheKey, serialized, options, cancellationToken);

        return viewModel;
    }
}
