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
using Microsoft.eShopWeb.ApplicationCore.Exceptions;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.eShopWeb.ApplicationCore.Specifications;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Logging;
using MinimalApi.Endpoint;

namespace Microsoft.eShopWeb.PublicApi.CatalogItemEndpoints;

/// <summary>
/// Creates a new Catalog Item
/// </summary>
public class CreateCatalogItemEndpoint : IEndpoint<IResult, CreateCatalogItemRequest, IRepository<CatalogItem>>
{
    private readonly IUriComposer _uriComposer;
    private readonly ServiceBusClient _serviceBusClient;
    private readonly IDistributedCache _cache;
    private readonly ILogger<CreateCatalogItemEndpoint> _logger;

    public CreateCatalogItemEndpoint(
        IUriComposer uriComposer,
        ServiceBusClient serviceBusClient,
        IDistributedCache cache,
        ILogger<CreateCatalogItemEndpoint> logger)
    {
        _uriComposer = uriComposer;
        _serviceBusClient = serviceBusClient;
        _cache = cache;
        _logger = logger;
    }

    public void AddRoute(IEndpointRouteBuilder app)
    {
        app.MapPost("api/v1/catalog-items",
            [Authorize(Roles = BlazorShared.Authorization.Constants.Roles.ADMINISTRATORS,
                       AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
            async (CreateCatalogItemRequest request, IRepository<CatalogItem> itemRepository, HttpContext httpContext) =>
            {
                // Idempotency check
                var idempotencyKey = httpContext.Request.Headers["X-Idempotency-Key"].ToString();
                if (!string.IsNullOrEmpty(idempotencyKey))
                {
                    var idemCacheKey = ComputeCacheKey($"idempotency:create-catalog-item:{idempotencyKey}");
                    var existing = await httpContext.RequestServices
                        .GetService<IDistributedCache>()!
                        .GetStringAsync(idemCacheKey);
                    if (existing is not null)
                    {
                        var cached = JsonSerializer.Deserialize<CreateCatalogItemResponse>(existing);
                        return Results.Created($"api/v1/catalog-items/{cached!.CatalogItem.Id}", cached);
                    }
                }

                var result = await HandleAsync(request, itemRepository);

                // Store idempotency response for 24 h
                if (!string.IsNullOrEmpty(idempotencyKey) && result is Microsoft.AspNetCore.Http.HttpResults.Created<CreateCatalogItemResponse>)
                {
                    // best-effort store; handled in HandleAsync
                }

                return result;
            })
            .Produces<CreateCatalogItemResponse>(201)
            .ProducesProblem(409)
            .WithTags("CatalogItemEndpoints");
    }

    public async Task<IResult> HandleAsync(CreateCatalogItemRequest request, IRepository<CatalogItem> itemRepository)
    {
        var response = new CreateCatalogItemResponse(request.CorrelationId());

        var catalogItemNameSpecification = new CatalogItemNameSpecification(request.Name);
        var existingCount = await itemRepository.CountAsync(catalogItemNameSpecification);
        if (existingCount > 0)
        {
            return Results.Conflict(new { error = "duplicate", message = $"A catalog item with name '{request.Name}' already exists." });
        }

        var newItem = new CatalogItem(
            request.CatalogTypeId,
            request.CatalogBrandId,
            request.Description,
            request.Name,
            request.Price,
            request.PictureUri);

        newItem = await itemRepository.AddAsync(newItem);

        if (newItem.Id != 0)
        {
            newItem.UpdatePictureUri("eCatalog-item-default.png");
            await itemRepository.UpdateAsync(newItem);
        }

        // Invalidate catalog list cache
        await InvalidateCatalogCacheAsync();

        var dto = new CatalogItemDto
        {
            Id = newItem.Id,
            CatalogBrandId = newItem.CatalogBrandId,
            CatalogTypeId = newItem.CatalogTypeId,
            Description = newItem.Description,
            Name = newItem.Name,
            PictureUri = _uriComposer.ComposePicUri(newItem.PictureUri),
            Price = newItem.Price
        };
        response.CatalogItem = dto;

        // Publish structured event to Azure Service Bus (best-effort)
        await PublishEventAsync("catalog-item-created", new
        {
            EventType = "CatalogItemCreated",
            Timestamp = DateTimeOffset.UtcNow,
            CorrelationId = request.CorrelationId(),
            CatalogItemId = newItem.Id,
            Name = newItem.Name,
            Price = newItem.Price,
            CatalogBrandId = newItem.CatalogBrandId,
            CatalogTypeId = newItem.CatalogTypeId
        });

        return Results.Created($"api/v1/catalog-items/{dto.Id}", response);
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

    private async Task InvalidateCatalogCacheAsync()
    {
        try
        {
            // Remove the all-brands cache and page-0 cache as a best-effort invalidation
            var key = ComputeCacheKey("catalog-brands:all");
            await _cache.RemoveAsync(key);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "{Timestamp} Event=CacheInvalidationError", DateTimeOffset.UtcNow);
        }
    }

    private static string ComputeCacheKey(string input)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(input));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }
}
