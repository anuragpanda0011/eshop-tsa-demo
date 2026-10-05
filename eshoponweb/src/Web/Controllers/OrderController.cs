using System.Text.Json;
using Ardalis.GuardClauses;
using Azure.Messaging.ServiceBus;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.eShopWeb.Web.Features.MyOrders;
using Microsoft.eShopWeb.Web.Features.OrderDetails;

namespace Microsoft.eShopWeb.Web.Controllers;

[ApiExplorerSettings(IgnoreApi = true)]
[Authorize]
[Route("[controller]/[action]")]
public class OrderController : Controller
{
    private readonly IMediator _mediator;
    private readonly IAppLogger<OrderController> _logger;
    private readonly ServiceBusClient? _serviceBusClient;
    private readonly string _eventsTopic;

    public OrderController(
        IMediator mediator,
        IAppLogger<OrderController> logger,
        ServiceBusClient? serviceBusClient = null)
    {
        _mediator = mediator;
        _logger = logger;
        _serviceBusClient = serviceBusClient;
        _eventsTopic = Environment.GetEnvironmentVariable("SERVICEBUS_EVENTS_TOPIC") ?? "order-events";
    }

    [HttpGet]
    public async Task<IActionResult> MyOrders()
    {
        Guard.Against.Null(User?.Identity?.Name, nameof(User.Identity.Name));

        _logger.LogInformation(
            "Fetching orders for user '{UserName}'.",
            User.Identity.Name);

        var viewModel = await _mediator.Send(new GetMyOrders(User.Identity.Name));
        return View(viewModel);
    }

    [HttpGet("{orderId}")]
    public async Task<IActionResult> Detail(int orderId)
    {
        Guard.Against.Null(User?.Identity?.Name, nameof(User.Identity.Name));

        _logger.LogInformation(
            "Fetching order detail for order '{OrderId}', user '{UserName}'.",
            orderId,
            User.Identity.Name);

        var viewModel = await _mediator.Send(new GetOrderDetails(User.Identity.Name, orderId));

        if (viewModel == null)
        {
            _logger.LogWarning(
                "Order '{OrderId}' not found for user '{UserName}'.",
                orderId,
                User.Identity.Name);
            return BadRequest("No such order found for this user.");
        }

        await PublishEventAsync("OrderDetailViewed", new
        {
            OrderId = orderId,
            UserName = User.Identity.Name,
            ViewedAt = DateTimeOffset.UtcNow
        });

        return View(viewModel);
    }

    private async Task PublishEventAsync(string eventType, object payload)
    {
        if (_serviceBusClient == null) return;
        try
        {
            var sender = _serviceBusClient.CreateSender(_eventsTopic);
            var body = JsonSerializer.Serialize(new
            {
                EventType = eventType,
                OccurredAt = DateTimeOffset.UtcNow,
                Payload = payload
            });
            var message = new ServiceBusMessage(body)
            {
                ContentType = "application/json",
                Subject = eventType
            };
            await sender.SendMessageAsync(message);
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Failed to publish event '{EventType}' to Service Bus: {Error}", eventType, ex.Message);
        }
    }
}
