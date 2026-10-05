using System;
using System.Text.Json;
using System.Threading.Tasks;
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
/// Get a Catalog Item by Id.
/// Route: GET /api/v1/catalog-items/{catalogItemId}
/// Individual items are cached in Redis for 5 minutes.
/// </summary>
public class CatalogItemGetByIdEndpoint : IEndpoint<IResult, GetByIdCatalogItemRequest, IRepository<CatalogItem>>
{
    private static readonly TimeSpan CacheTtl = TimeSpan.FromMinutes(5);

    private readonly IUriComposer _uriComposer;
    private readonly IDistributedCache _cache;
    private readonly ILogger<CatalogItemGetByIdEndpoint> _logger;

    public CatalogItemGetByIdEndpoint(
        IUriComposer uriComposer,
        IDistributedCache cache,
        ILogger<CatalogItemGetByIdEndpoint> logger)
    {
        _uriComposer = uriComposer;
        _cache       = cache;
        _logger      = logger;
    }

    public void AddRoute(IEndpointRouteBuilder app)
    {
        app.MapGet("/api/v1/catalog-items/{catalogItemId}",
                async (int catalogItemId, IRepository<CatalogItem> itemRepository) =>
                    await HandleAsync(new GetByIdCatalogItemRequest(catalogItemId), itemRepository))
           .Produces<GetByIdCatalogItemResponse>()
           .Produces<ErrorResponse>(StatusCodes.Status404NotFound)
           .WithTags("CatalogItemEndpoints");
    }

    public async Task<IResult> HandleAsync(
        GetByIdCatalogItemRequest request,
        IRepository<CatalogItem> itemRepository)
    {
        var traceId  = System.Diagnostics.Activity.Current?.TraceId.ToString() ?? string.Empty;
        var cacheKey = $"catalog:item:{request.CatalogItemId}";

        // Try Redis cache first.
        try
        {
            var cached = await _cache.GetStringAsync(cacheKey);
            if (cached is not null)
            {
                var cachedResponse = JsonSerializer.Deserialize<GetByIdCatalogItemResponse>(cached);
                if (cachedResponse is not null)
                {
                    _logger.LogInformation(JsonSerializer.Serialize(new
                    {
                        timestamp = DateTimeOffset.UtcNow.ToString("o"),
                        traceId,
                        @event    = "CatalogItemGetByIdCacheHit",
                        itemId    = request.CatalogItemId
                    }));
                    return Results.Ok(cachedResponse);
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(JsonSerializer.Serialize(new
            {
                timestamp = DateTimeOffset.UtcNow.ToString("o"),
                traceId,
                @event    = "CatalogItemGetByIdCacheReadFailed",
                itemId    = request.CatalogItemId,
                error     = ex.Message
            }));
        }

        var item = await itemRepository.GetByIdAsync(request.CatalogItemId);
        if (item is null)
        {
            return Results.NotFound(new ErrorResponse("not_found",
                $"Catalog item {request.CatalogItemId} was not found."));
        }

        var response = new GetByIdCatalogItemResponse(request.CorrelationId())
        {
            CatalogItem = new CatalogItemDto
            {
                Id              = item.Id,
                CatalogBrandId  = item.CatalogBrandId,
                CatalogTypeId   = item.CatalogTypeId,
                Description     = item.Description,
                Name            = item.Name,
                PictureUri      = _uriComposer.ComposePicUri(item.PictureUri),
                Price           = item.Price
            }
        };

        // Populate cache best-effort.
        try
        {
            await _cache.SetStringAsync(cacheKey, JsonSerializer.Serialize(response),
                new DistributedCacheEntryOptions
                {
                    AbsoluteExpirationRelativeToNow = CacheTtl
                });
        }
        catch (Exception ex)
        {
            _logger.LogWarning(JsonSerializer.Serialize(new
            {
                timestamp = DateTimeOffset.UtcNow.ToString("o"),
                traceId,
                @event    = "CatalogItemGetByIdCacheWriteFailed",
                itemId    = request.CatalogItemId,
                error     = ex.Message
            }));
        }

        _logger.LogInformation(JsonSerializer.Serialize(new
        {
            timestamp = DateTimeOffset.UtcNow.ToString("o"),
            traceId,
            @event    = "CatalogItemGetByIdFetched",
            itemId    = request.CatalogItemId
        }));

        return Results.Ok(response);
    }
}
