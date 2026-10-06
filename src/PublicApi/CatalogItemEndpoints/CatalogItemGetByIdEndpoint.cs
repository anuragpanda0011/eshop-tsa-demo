using System;
using System.Security.Cryptography;
using System.Text;
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
/// Get a Catalog Item by Id
/// </summary>
public class CatalogItemGetByIdEndpoint : IEndpoint<IResult, GetByIdCatalogItemRequest, IRepository<CatalogItem>>
{
    private readonly IUriComposer _uriComposer;
    private readonly IDistributedCache _cache;
    private readonly ILogger<CatalogItemGetByIdEndpoint> _logger;
    private const int CacheTtlSeconds = 120;

    public CatalogItemGetByIdEndpoint(IUriComposer uriComposer, IDistributedCache cache, ILogger<CatalogItemGetByIdEndpoint> logger)
    {
        _uriComposer = uriComposer;
        _cache = cache;
        _logger = logger;
    }

    public void AddRoute(IEndpointRouteBuilder app)
    {
        app.MapGet("api/v1/catalog-items/{catalogItemId}",
            async (int catalogItemId, IRepository<CatalogItem> itemRepository) =>
            {
                return await HandleAsync(new GetByIdCatalogItemRequest(catalogItemId), itemRepository);
            })
            .Produces<GetByIdCatalogItemResponse>()
            .ProducesProblem(404)
            .WithTags("CatalogItemEndpoints");
    }

    public async Task<IResult> HandleAsync(GetByIdCatalogItemRequest request, IRepository<CatalogItem> itemRepository)
    {
        var cacheKey = ComputeCacheKey($"catalog-item:{request.CatalogItemId}");

        try
        {
            var cached = await _cache.GetStringAsync(cacheKey);
            if (cached is not null)
            {
                _logger.LogInformation("{Timestamp} Event=CacheHit Key={Key}", DateTimeOffset.UtcNow, cacheKey);
                var cachedResponse = JsonSerializer.Deserialize<GetByIdCatalogItemResponse>(cached);
                return Results.Ok(cachedResponse);
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "{Timestamp} Event=CacheReadError Key={Key}", DateTimeOffset.UtcNow, cacheKey);
        }

        var response = new GetByIdCatalogItemResponse(request.CorrelationId());
        var item = await itemRepository.GetByIdAsync(request.CatalogItemId);
        if (item is null)
        {
            return Results.NotFound(new { error = "not_found", message = $"Catalog item {request.CatalogItemId} was not found." });
        }

        response.CatalogItem = new CatalogItemDto
        {
            Id = item.Id,
            CatalogBrandId = item.CatalogBrandId,
            CatalogTypeId = item.CatalogTypeId,
            Description = item.Description,
            Name = item.Name,
            PictureUri = _uriComposer.ComposePicUri(item.PictureUri),
            Price = item.Price
        };

        try
        {
            var serialized = JsonSerializer.Serialize(response);
            await _cache.SetStringAsync(cacheKey, serialized, new DistributedCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = TimeSpan.FromSeconds(CacheTtlSeconds)
            });
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "{Timestamp} Event=CacheWriteError Key={Key}", DateTimeOffset.UtcNow, cacheKey);
        }

        return Results.Ok(response);
    }

    private static string ComputeCacheKey(string input)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(input));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }
}
