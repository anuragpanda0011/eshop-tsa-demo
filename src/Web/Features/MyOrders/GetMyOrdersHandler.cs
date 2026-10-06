using System.Text.Json;
using MediatR;
using Microsoft.eShopWeb.ApplicationCore.Entities.OrderAggregate;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.eShopWeb.ApplicationCore.Specifications;
using Microsoft.eShopWeb.Web.Extensions;
using Microsoft.eShopWeb.Web.ViewModels;
using Microsoft.Extensions.Caching.Distributed;

namespace Microsoft.eShopWeb.Web.Features.MyOrders;

public class GetMyOrdersHandler : IRequestHandler<GetMyOrders, IEnumerable<OrderViewModel>>
{
    private readonly IReadRepository<Order> _orderRepository;
    private readonly IDistributedCache _cache;
    private readonly IAppLogger<GetMyOrdersHandler> _logger;

    public GetMyOrdersHandler(
        IReadRepository<Order> orderRepository,
        IDistributedCache cache,
        IAppLogger<GetMyOrdersHandler> logger)
    {
        _orderRepository = orderRepository;
        _cache = cache;
        _logger = logger;
    }

    public async Task<IEnumerable<OrderViewModel>> Handle(
        GetMyOrders request,
        CancellationToken cancellationToken)
    {
        // Hash user-supplied string before using as cache key
        var cacheKey = CacheHelpers.HashKey($"my-orders-{request.UserName}");

        var cached = await _cache.GetStringAsync(cacheKey, cancellationToken);
        if (cached != null)
        {
            _logger.LogInformation("Cache hit for orders of user '{UserName}'.", request.UserName);
            var cachedOrders = JsonSerializer.Deserialize<IEnumerable<OrderViewModel>>(cached);
            if (cachedOrders != null) return cachedOrders;
        }

        var specification = new CustomerOrdersSpecification(request.UserName);
        var orders = await _orderRepository.ListAsync(specification, cancellationToken);

        var result = orders.Select(o => new OrderViewModel
        {
            OrderDate = o.OrderDate,
            OrderNumber = o.Id,
            ShippingAddress = o.ShipToAddress,
            Total = o.Total()
        }).ToList();

        var serialized = JsonSerializer.Serialize(result);
        var options = new DistributedCacheEntryOptions
        {
            AbsoluteExpirationRelativeToNow = CacheHelpers.DefaultCacheDuration
        };
        await _cache.SetStringAsync(cacheKey, serialized, options, cancellationToken);

        return result;
    }
}
