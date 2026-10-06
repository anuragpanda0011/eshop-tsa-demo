using System.Threading;
using System.Threading.Tasks;

namespace Microsoft.eShopWeb.ApplicationCore.Interfaces;

/// <summary>
/// Publishes structured JSON domain events to Azure Service Bus.
/// Implementations must be best-effort: log failures but never throw.
/// </summary>
public interface IServiceBusPublisher
{
    /// <summary>
    /// Publishes a structured domain event as a JSON message to the configured
    /// Azure Service Bus topic or queue.
    /// </summary>
    /// <param name="eventName">Logical event name used as the message subject.</param>
    /// <param name="payload">Strongly-typed payload object; serialised to JSON internally.</param>
    /// <param name="cancellationToken">Optional cancellation token.</param>
    Task PublishAsync<T>(string eventName, T payload, CancellationToken cancellationToken = default)
        where T : class;
}
