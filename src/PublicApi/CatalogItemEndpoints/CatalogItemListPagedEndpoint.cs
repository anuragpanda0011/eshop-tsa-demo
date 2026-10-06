using System;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
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
/// List Catalog Items (paged)
/// </summary>
public class CatalogItemListPagedEndpoint : IEndpoint<IResult, ListPagedCatalogItemRequest, IRepository<CatalogItem>>
{
    private readonly IUriComposer _uriComposer;
    private readonly IMapper _mapper;
    private readonly IDistributedCache _cache;
    private readonly ILogger<CatalogItemListPagedEndpoint> _logger;
    private const int CacheTtlSeconds = 60;

    public CatalogItemListPagedEndpoint(
        IUriComposer uriComposer,
        IMapper mapper,
        IDistributedCache cache,
        ILogger<CatalogItemListPagedEndpoint> logger)
    {
        _uriComposer = uriComposer;
        _mapper = mapper;
        _cache = cache;
        _logger = logger;
    }

    public void AddRoute(IEndpointRouteBuilder app)
    {
        app.MapGet("api/v1/catalog-items",
            async (int? pageSize, int? pageIndex, int? catalogBrandId, int? catalogTypeId,
                   IRepository<CatalogItem> itemRepository) =>
            {
                return await HandleAsync(
                    new ListPagedCatalogItemRequest(pageSize, pageIndex, catalogBrandId, catalogTypeId),
                    itemRepository);
            })
            .Produces<ListPagedCatalogItemResponse>()
            .WithTags("CatalogItemEndpoints");
    }

    public async Task<IResult> HandleAsync(ListPagedCatalogItemRequest request, IRepository<CatalogItem> itemRepository)
    {
        var rawKey = $"catalog-items:pi={request.PageIndex}:ps={request.PageSize}:brand={request.CatalogBrandId}:type={request.CatalogTypeId}";
        var cacheKey = ComputeCacheKey(rawKey);

        try
        {
            var cached = await _cache.GetStringAsync(cacheKey);
            if (cached is not null)
            {
                _logger.LogInformation("{Timestamp} Event=CacheHit Key={Key}", DateTimeOffset.UtcNow, cacheKey);
                var cachedResponse = JsonSerializer.Deserialize<ListPagedCatalogItemResponse>(cached);
                return Results.Ok(cachedResponse);
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "{Timestamp} Event=CacheReadError Key={Key}", DateTimeOffset.UtcNow, cacheKey);
        }

        var response = new ListPagedCatalogItemResponse(request.CorrelationId());

        var filterSpec = new CatalogFilterSpecification(request.CatalogBrandId, request.CatalogTypeId);
        int totalItems = await itemRepository.CountAsync(filterSpec);

        var pagedSpec = new CatalogFilterPaginatedSpecification(
            skip: request.PageIndex * request.PageSize,
            take: request.PageSize,
            brandId: request.CatalogBrandId,
            typeId: request.CatalogTypeId);

        var items = await itemRepository.ListAsync(pagedSpec);

        response.CatalogItems.AddRange(items.Select(_mapper.Map<CatalogItemDto>));
        foreach (CatalogItemDto item in response.CatalogItems)
        {
            item.PictureUri = _uriComposer.ComposePicUri(item.PictureUri);
        }

        response.PageCount = request.PageSize > 0
            ? (int)Math.Ceiling((decimal)totalItems / request.PageSize)
            : (totalItems > 0 ? 1 : 0);

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
