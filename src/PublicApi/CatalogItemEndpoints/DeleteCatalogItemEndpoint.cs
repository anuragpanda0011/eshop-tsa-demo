using System;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Azure.Messaging.ServiceBus;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.eShopWeb.ApplicationCore.Entities;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Logging;
using MinimalApi.Endpoint;

namespace Microsoft.eShopWeb.PublicApi.CatalogItemEndpoints;

/// <summary>
/// Deletes a Catalog Item
/// </summary>
public class DeleteCatalogItemEndpoint : IEndpoint<IResult, DeleteCatalogItemRequest, IRepository<CatalogItem>>
{
    private readonly ServiceBusClient _serviceBusClient;
    private readonly IDistributedCache _cache;
    private readonly ILogger<DeleteCatalogItemEndpoint> _logger;

    public DeleteCatalogItemEndpoint(
        ServiceBusClient serviceBusClient,
        IDistributedCache cache,
        ILogger<DeleteCatalogItemEndpoint> logger)
    {
        _serviceBusClient = serviceBusClient;
        _cache = cache;
        _logger = logger;
    }

    public void AddRoute(IEndpointRouteBuilder app)
    {
        app.MapDelete("api/v1/catalog-items/{catalogItemId}",
            [Authorize(Roles = BlazorShared.Authorization.Constants.Roles.ADMINISTRATORS,
                       AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
            async (int catalogItemId, IRepository<CatalogItem> itemRepository) =>
            {
                return await HandleAsync(new DeleteCatalogItemRequest(catalogItemId), itemRepository);
            })
            .Produces<DeleteCatalogItemResponse>()
            .ProducesProblem(404)
            .WithTags("CatalogItemEndpoints");
    }

    public async Task<IResult> HandleAsync(DeleteCatalogItemRequest request, IRepository<CatalogItem> itemRepository)
    {
        var response = new DeleteCatalogItemResponse(request.CorrelationId());

        var itemToDelete = await itemRepository.GetByIdAsync(request.CatalogItemId);
        if (itemToDelete is null)
        {
            return Results.NotFound(new { error = "not_found", message = $"Catalog item {request.CatalogItemId} was not found." });
        }

        await itemRepository.DeleteAsync(itemToDelete);

        // Invalidate caches
        await InvalidateCatalogItemCacheAsync(request.CatalogItemId);

        // Publish structured event to Azure Service Bus (best-effort)
        await PublishEventAsync("catalog-item-deleted", new
        {
            EventType = "CatalogItemDeleted",
            Timestamp = DateTimeOffset.UtcNow,
            CorrelationId = request.CorrelationId(),
            CatalogItemId = request.CatalogItemId
        });

        return Results.Ok(response);
    }

    private async Task PublishEventAsync(string topic, object payload)
    {
        try
        {
            var sender = _serviceBusClient.CreateSender(topic);
            var json = JsonSerializer.Serialize(payload);
            var message = new ServiceBusMessage(Encoding.UTF8.GetBytes(json))
            {
                ContentType = "application/json"
            };
            await sender.SendMessageAsync(message);
            _logger.LogInformation("{Timestamp} Event=ServiceBusPublish Topic={Topic}", DateTimeOffset.UtcNow, topic);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "{Timestamp} Event=ServiceBusPublishError Topic={Topic}", DateTimeOffset.UtcNow, topic);
        }
    }

    private async Task InvalidateCatalogItemCacheAsync(int itemId)
    {
        try
        {
            var itemKey = ComputeCacheKey($"catalog-item:{itemId}");
            await _cache.RemoveAsync(itemKey);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "{Timestamp} Event=CacheInvalidationError ItemId={ItemId}", DateTimeOffset.UtcNow, itemId);
        }
    }

    private static string ComputeCacheKey(string input)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(input));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }
}
