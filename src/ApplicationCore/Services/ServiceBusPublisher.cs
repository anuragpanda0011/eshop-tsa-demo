using System;
using System.Threading;
using System.Threading.Tasks;
using Azure.Messaging.ServiceBus;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.ApplicationCore.Services;

/// <summary>
/// Publishes structured JSON domain events to Azure Service Bus.
/// All publishes are best-effort: failures are logged and swallowed so that
/// primary business operations are never blocked by messaging infrastructure.
/// </summary>
public class ServiceBusPublisher : IServiceBusPublisher, IAsyncDisposable
{
    private readonly ServiceBusClient _client;
    private readonly string _topicOrQueueName;
    private readonly ILogger<ServiceBusPublisher> _logger;

    /// <summary>
    /// Creates a new <see cref="ServiceBusPublisher"/>.
    /// </summary>
    /// <param name="connectionString">
    /// Azure Service Bus connection string — read from environment variable
    /// <c>SERVICEBUS_CONNECTION_STRING</c> or injected via Azure Key Vault.
    /// </param>
    /// <param name="topicOrQueueName">
    /// Target topic or queue name — read from environment variable
    /// <c>SERVICEBUS_TOPIC_NAME</c> or application configuration.
    /// </param>
    /// <param name="logger">Structured logger.</param>
    public ServiceBusPublisher(
        string connectionString,
        string topicOrQueueName,
        ILogger<ServiceBusPublisher> logger)
    {
        if (string.IsNullOrWhiteSpace(connectionString))
            throw new ArgumentException(
                "Azure Service Bus connection string must not be empty. " +
                "Set the environment variable 'SERVICEBUS_CONNECTION_STRING'.",
                nameof(connectionString));

        if (string.IsNullOrWhiteSpace(topicOrQueueName))
            throw new ArgumentException(
                "Azure Service Bus topic/queue name must not be empty. " +
                "Set the environment variable 'SERVICEBUS_TOPIC_NAME'.",
                nameof(topicOrQueueName));

        _topicOrQueueName = topicOrQueueName;
        _logger = logger;

        // ServiceBusClient is thread-safe and should be reused for the lifetime
        // of the application.
        _client = new ServiceBusClient(connectionString,
            new ServiceBusClientOptions
            {
                TransportType = ServiceBusTransportType.AmqpTcp
            });
    }

    /// <inheritdoc />
    public async Task PublishAsync<T>(
        string eventName,
        T payload,
        CancellationToken cancellationToken = default)
        where T : class
    {
        try
        {
            var envelope = new
            {
                EventName = eventName,
                OccurredAt = DateTimeOffset.UtcNow,
                Payload = payload
            };

            var json = envelope.ToJson();
            var message = new ServiceBusMessage(json)
            {
                Subject = eventName,
                ContentType = "application/json"
            };

            await using var sender = _client.CreateSender(_topicOrQueueName);
            await sender.SendMessageAsync(message, cancellationToken);

            _logger.LogInformation(
                "ServiceBus event published. EventName={EventName} Topic={Topic}",
                eventName, _topicOrQueueName);
        }
        catch (Exception ex)
        {
            // Best-effort: log and continue — do not propagate to caller
            _logger.LogWarning(ex,
                "Failed to publish ServiceBus event. EventName={EventName} Topic={Topic} Error={Error}",
                eventName, _topicOrQueueName, ex.Message);
        }
    }

    public async ValueTask DisposeAsync()
    {
        await _client.DisposeAsync();
    }
}
