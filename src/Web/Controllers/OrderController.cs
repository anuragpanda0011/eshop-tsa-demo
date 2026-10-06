using Ardalis.GuardClauses;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.eShopWeb.Web.Features.MyOrders;
using Microsoft.eShopWeb.Web.Features.OrderDetails;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.Web.Controllers;

[ApiExplorerSettings(IgnoreApi = true)]
[Authorize]
[Route("[controller]/[action]")]
public class OrderController : Controller
{
    private readonly IMediator _mediator;
    private readonly ILogger<OrderController> _logger;

    public OrderController(IMediator mediator, ILogger<OrderController> logger)
    {
        _mediator = mediator;
        _logger = logger;
    }

    [HttpGet]
    public async Task<IActionResult> MyOrders()
    {
        Guard.Against.Null(User?.Identity?.Name, nameof(User.Identity.Name));

        _logger.LogInformation("MyOrders requested by User={User} TraceId={TraceId}",
            User.Identity.Name, HttpContext.TraceIdentifier);

        var viewModel = await _mediator.Send(new GetMyOrders(User.Identity.Name));

        return View(viewModel);
    }

    [HttpGet("{orderId}")]
    public async Task<IActionResult> Detail(int orderId)
    {
        Guard.Against.Null(User?.Identity?.Name, nameof(User.Identity.Name));

        _logger.LogInformation("OrderDetail requested. OrderId={OrderId} User={User} TraceId={TraceId}",
            orderId, User.Identity.Name, HttpContext.TraceIdentifier);

        var viewModel = await _mediator.Send(new GetOrderDetails(User.Identity.Name, orderId));

        if (viewModel == null)
        {
            _logger.LogWarning("OrderDetail not found. OrderId={OrderId} User={User} TraceId={TraceId}",
                orderId, User.Identity.Name, HttpContext.TraceIdentifier);
            return BadRequest(new { error = "order_not_found", message = "No such order found for this user." });
        }

        return View(viewModel);
    }
}
