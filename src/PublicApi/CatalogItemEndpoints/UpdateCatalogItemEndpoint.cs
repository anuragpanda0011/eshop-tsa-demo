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
/// Updates a Catalog Item
/// </summary>
public class UpdateCatalogItemEndpoint : IEndpoint<IResult, UpdateCatalogItemRequest, IRepository<CatalogItem>>
{
    private readonly IUriComposer _uriComposer;
    private readonly ServiceBusClient _serviceBusClient;
    private readonly IDistributedCache _cache;
    private readonly ILogger<UpdateCatalogItemEndpoint> _logger;

    public UpdateCatalogItemEndpoint(
        IUriComposer uriComposer,
        ServiceBusClient serviceBusClient,
        IDistributedCache cache,
        ILogger<UpdateCatalogItemEndpoint> logger)
    {
        _uriComposer = uriComposer;
        _serviceBusClient = serviceBusClient;
        _cache = cache;
        _logger = logger;
    }

    public void AddRoute(IEndpointRouteBuilder app)
    {
        app.MapPut("api/v1/catalog-items",
            [Authorize(Roles = BlazorShared.Authorization.Constants.Roles.ADMINISTRATORS,
                       AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
            async (UpdateCatalogItemRequest request, IRepository<CatalogItem> itemRepository, HttpContext httpContext) =>
            {
                // Idempotency check
                var idempotencyKey = httpContext.Request.Headers["X-Idempotency-Key"].ToString();
                if (!string.IsNullOrEmpty(idempotencyKey))
                {
                    var idemCacheKey = ComputeCacheKey($"idempotency:update-catalog-item:{idempotencyKey}");
                    var existing = await httpContext.RequestServices
                        .GetService<IDistributedCache>()!
                        .GetStringAsync(idemCacheKey);
                    if (existing is not null)
                    {
                        var cachedResponse = JsonSerializer.Deserialize<UpdateCatalogItemResponse>(existing);
                        return Results.Ok(cachedResponse);
                    }
                }

                var result = await HandleAsync(request, itemRepository);

                // Store idempotency key response for 24 h (best-effort)
                if (!string.IsNullOrEmpty(idempotencyKey) && result is Microsoft.AspNetCore.Http.HttpResults.Ok<UpdateCatalogItemResponse> okResult)
                {
                    try
                    {
                        var idemCacheKey = ComputeCacheKey($"idempotency:update-catalog-item:{idempotencyKey}");
                        var serialized = JsonSerializer.Serialize(okResult.Value);
                        await httpContext.RequestServices
                            .GetService<IDistributedCache>()!
                            .SetStringAsync(idemCacheKey, serialized, new DistributedCacheEntryOptions
                            {
                                AbsoluteExpirationRelativeToNow = TimeSpan.FromHours(24)
                            });
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, "{Timestamp} Event=IdempotencyStoreError", DateTimeOffset.UtcNow);
                    }
                }

                return result;
            })
            .Produces<UpdateCatalogItemResponse>()
            .ProducesProblem(404)
            .WithTags("CatalogItemEndpoints");
    }

    public async Task<IResult> HandleAsync(UpdateCatalogItemRequest request, IRepository<CatalogItem> itemRepository)
    {
        var response = new UpdateCatalogItemResponse(request.CorrelationId());

        var existingItem = await itemRepository.GetByIdAsync(request.Id);
        if (existingItem is null)
        {
            return Results.NotFound(new { error = "not_found", message = $"Catalog item {request.Id} was not found." });
        }

        CatalogItem.CatalogItemDetails details = new(request.Name, request.Description, request.Price);
        existingItem.UpdateDetails(details);
        existingItem.UpdateBrand(request.CatalogBrandId);
        existingItem.UpdateType(request.CatalogTypeId);

        await itemRepository.UpdateAsync(existingItem);

        // Invalidate cache for this item
        await InvalidateCatalogItemCacheAsync(existingItem.Id);

        var dto = new CatalogItemDto
        {
            Id = existingItem.Id,
            CatalogBrandId = existingItem.CatalogBrandId,
            CatalogTypeId = existingItem.CatalogTypeId,
            Description = existingItem.Description,
            Name = existingItem.Name,
            PictureUri = _uriComposer.ComposePicUri(existingItem.PictureUri),
            Price = existingItem.Price
        };
        response.CatalogItem = dto;

        // Publish structured event to Azure Service Bus (best-effort)
        await PublishEventAsync("catalog-item-updated", new
        {
            EventType = "CatalogItemUpdated",
            Timestamp = DateTimeOffset.UtcNow,
            CorrelationId = request.CorrelationId(),
            CatalogItemId = existingItem.Id,
            Name = existingItem.Name,
            Price = existingItem.Price,
            CatalogBrandId = existingItem.CatalogBrandId,
            CatalogTypeId = existingItem.CatalogTypeId
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
            var key = ComputeCacheKey($"catalog-item:{itemId}");
            await _cache.RemoveAsync(key);
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
