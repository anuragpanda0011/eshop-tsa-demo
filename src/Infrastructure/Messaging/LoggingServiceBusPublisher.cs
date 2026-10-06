using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.Infrastructure.Messaging;

/// <summary>
/// Local implementation of <see cref="IServiceBusPublisher"/>.
///
/// The modernization agent introduced IServiceBusPublisher and made OrderService
/// and BasketService depend on it, but produced no implementation and no DI
/// registration, so the container failed validation and the app aborted at
/// startup. This publisher satisfies the contract without an Azure Service Bus
/// namespace: events are serialised and written to the log, which is what the
/// interface's own "best-effort, never throw" guarantee allows.
/// </summary>
public sealed class LoggingServiceBusPublisher : IServiceBusPublisher
{
    private readonly ILogger<LoggingServiceBusPublisher> _logger;

    public LoggingServiceBusPublisher(ILogger<LoggingServiceBusPublisher> logger) => _logger = logger;

    public Task PublishAsync<T>(string eventName, T payload) where T : class
    {
        try
        {
            _logger.LogInformation("ServiceBus event {EventName}: {Payload}",
                eventName, JsonSerializer.Serialize(payload));
        }
        catch (JsonException ex)
        {
            _logger.LogWarning(ex, "Could not serialise payload for event {EventName}", eventName);
        }
        return Task.CompletedTask;
    }
}
