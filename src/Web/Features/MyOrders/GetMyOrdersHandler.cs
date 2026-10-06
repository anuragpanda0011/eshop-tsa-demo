using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using MediatR;
using Microsoft.eShopWeb.ApplicationCore.Entities.OrderAggregate;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.eShopWeb.ApplicationCore.Specifications;
using Microsoft.eShopWeb.Web.ViewModels;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.Web.Features.MyOrders;

public class GetMyOrdersHandler : IRequestHandler<GetMyOrders, IEnumerable<OrderViewModel>>
{
    private readonly IReadRepository<Order> _orderRepository;
    private readonly ILogger<GetMyOrdersHandler> _logger;

    public GetMyOrdersHandler(IReadRepository<Order> orderRepository, ILogger<GetMyOrdersHandler> logger)
    {
        _orderRepository = orderRepository;
        _logger = logger;
    }

    public async Task<IEnumerable<OrderViewModel>> Handle(GetMyOrders request,
        CancellationToken cancellationToken)
    {
        _logger.LogInformation("Fetching orders for User={User}", request.UserName);

        var specification = new CustomerOrdersSpecification(request.UserName);
        var orders = await _orderRepository.ListAsync(specification, cancellationToken);

        return orders.Select(o => new OrderViewModel
        {
            OrderDate = o.OrderDate,
            OrderNumber = o.Id,
            ShippingAddress = o.ShipToAddress,
            Total = o.Total()
        });
    }
}
