using System.Threading.Tasks;

namespace Microsoft.eShopWeb.ApplicationCore.Interfaces;

/// <summary>
/// Publishes structured JSON domain events to Azure Service Bus.
/// Implementations must be best-effort: callers should not throw on failure.
/// </summary>
public interface IServiceBusPublisher
{
    /// <summary>
    /// Publishes a structured event. Errors are logged but not re-thrown.
    /// </summary>
    /// <param name="eventName">Logical event name used as the Service Bus subject.</param>
    /// <param name="payload">Event payload — will be serialised to JSON.</param>
    Task PublishAsync<T>(string eventName, T payload) where T : class;
}
