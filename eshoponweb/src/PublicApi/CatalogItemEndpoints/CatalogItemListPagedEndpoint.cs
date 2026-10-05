using System;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using AutoMapper;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.eShopWeb.ApplicationCore.Entities;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.eShopWeb.ApplicationCore.Specifications;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Logging;
using MinimalApi.Endpoint;

namespace Microsoft.eShopWeb.PublicApi.CatalogItemEndpoints;

/// <summary>
/// List Catalog Items (paged).
/// Route: GET /api/v1/catalog-items
/// Results are cached in Redis for 2 minutes keyed on the query parameters.
/// </summary>
public class CatalogItemListPagedEndpoint : IEndpoint<IResult, ListPagedCatalogItemRequest, IRepository<CatalogItem>>
{
    private static readonly TimeSpan CacheTtl = TimeSpan.FromMinutes(2);

    private readonly IUriComposer _uriComposer;
    private readonly IMapper _mapper;
    private readonly IDistributedCache _cache;
    private readonly ILogger<CatalogItemListPagedEndpoint> _logger;

    public CatalogItemListPagedEndpoint(
        IUriComposer uriComposer,
        IMapper mapper,
        IDistributedCache cache,
        ILogger<CatalogItemListPagedEndpoint> logger)
    {
        _uriComposer = uriComposer;
        _mapper      = mapper;
        _cache       = cache;
        _logger      = logger;
    }

    public void AddRoute(IEndpointRouteBuilder app)
    {
        app.MapGet("/api/v1/catalog-items",
                async (int? pageSize, int? pageIndex, int? catalogBrandId, int? catalogTypeId,
                       IRepository<CatalogItem> itemRepository) =>
                    await HandleAsync(
                        new ListPagedCatalogItemRequest(pageSize, pageIndex, catalogBrandId, catalogTypeId),
                        itemRepository))
           .Produces<ListPagedCatalogItemResponse>()
           .Produces<ErrorResponse>(StatusCodes.Status500InternalServerError)
           .WithTags("CatalogItemEndpoints");
    }

    public async Task<IResult> HandleAsync(
        ListPagedCatalogItemRequest request,
        IRepository<CatalogItem> itemRepository)
    {
        var traceId = System.Diagnostics.Activity.Current?.TraceId.ToString() ?? string.Empty;

        // Build a deterministic, collision-resistant cache key from query parameters.
        // We hash the composite key so that user-supplied values cannot influence Redis key structure.
        var rawKey  = $"catalog:items:paged|sz={request.PageSize}|pg={request.PageIndex}|br={request.CatalogBrandId}|ty={request.CatalogTypeId}";
        var cacheKey = ComputeSha256CacheKey(rawKey);

        // Try Redis cache first.
        try
        {
            var cached = await _cache.GetStringAsync(cacheKey);
            if (cached is not null)
            {
                var cachedResponse = JsonSerializer.Deserialize<ListPagedCatalogItemResponse>(cached);
                if (cachedResponse is not null)
                {
                    _logger.LogInformation(JsonSerializer.Serialize(new
                    {
                        timestamp = DateTimeOffset.UtcNow.ToString("o"),
                        traceId,
                        @event    = "CatalogItemListPagedCacheHit",
                        cacheKey
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
                @event    = "CatalogItemListPagedCacheReadFailed",
                error     = ex.Message
            }));
        }

        var response   = new ListPagedCatalogItemResponse(request.CorrelationId());
        var filterSpec = new CatalogFilterSpecification(request.CatalogBrandId, request.CatalogTypeId);
        int totalItems = await itemRepository.CountAsync(filterSpec);

        var pagedSpec = new CatalogFilterPaginatedSpecification(
            skip:    request.PageIndex * request.PageSize,
            take:    request.PageSize,
            brandId: request.CatalogBrandId,
            typeId:  request.CatalogTypeId);

        var items = await itemRepository.ListAsync(pagedSpec);

        response.CatalogItems.AddRange(items.Select(_mapper.Map<CatalogItemDto>));
        foreach (var item in response.CatalogItems)
        {
            item.PictureUri = _uriComposer.ComposePicUri(item.PictureUri);
        }

        response.PageCount = request.PageSize > 0
            ? (int)Math.Ceiling((decimal)totalItems / request.PageSize)
            : (totalItems > 0 ? 1 : 0);

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
                @event    = "CatalogItemListPagedCacheWriteFailed",
                error     = ex.Message
            }));
        }

        _logger.LogInformation(JsonSerializer.Serialize(new
        {
            timestamp  = DateTimeOffset.UtcNow.ToString("o"),
            traceId,
            @event     = "CatalogItemListPagedFetched",
            totalItems,
            pageCount  = response.PageCount
        }));

        return Results.Ok(response);
    }

    /// <summary>
    /// Hashes the user-influenced composite key with SHA-256 before using it as a Redis key,
    /// preventing key-injection attacks and keeping keys a fixed, safe length.
    /// </summary>
    private static string ComputeSha256CacheKey(string input)
    {
        var bytes = System.Security.Cryptography.SHA256.HashData(
            System.Text.Encoding.UTF8.GetBytes(input));
        return "catalog:items:paged:" + Convert.ToHexString(bytes).ToLowerInvariant();
    }
}
