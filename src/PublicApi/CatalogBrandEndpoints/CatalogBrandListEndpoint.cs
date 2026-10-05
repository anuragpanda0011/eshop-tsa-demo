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
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Logging;
using MinimalApi.Endpoint;

namespace Microsoft.eShopWeb.PublicApi.CatalogBrandEndpoints;

/// <summary>
/// List Catalog Brands
/// Route: GET /api/v1/catalog-brands
/// Results are cached in Redis for 5 minutes.
/// </summary>
public class CatalogBrandListEndpoint : IEndpoint<IResult, IRepository<CatalogBrand>>
{
    private const string CacheKey = "catalog:brands:list";
    private static readonly TimeSpan CacheTtl = TimeSpan.FromMinutes(5);

    private readonly IMapper _mapper;
    private readonly IDistributedCache _cache;
    private readonly ILogger<CatalogBrandListEndpoint> _logger;

    public CatalogBrandListEndpoint(
        IMapper mapper,
        IDistributedCache cache,
        ILogger<CatalogBrandListEndpoint> logger)
    {
        _mapper = mapper;
        _cache  = cache;
        _logger = logger;
    }

    public void AddRoute(IEndpointRouteBuilder app)
    {
        app.MapGet("/api/v1/catalog-brands",
                async (IRepository<CatalogBrand> catalogBrandRepository) =>
                    await HandleAsync(catalogBrandRepository))
           .Produces<ListCatalogBrandsResponse>()
           .Produces<ErrorResponse>(StatusCodes.Status500InternalServerError)
           .WithTags("CatalogBrandEndpoints");
    }

    public async Task<IResult> HandleAsync(IRepository<CatalogBrand> catalogBrandRepository)
    {
        var traceId = System.Diagnostics.Activity.Current?.TraceId.ToString() ?? string.Empty;

        // Try cache first.
        try
        {
            var cached = await _cache.GetStringAsync(CacheKey);
            if (cached is not null)
            {
                var cachedResponse = JsonSerializer.Deserialize<ListCatalogBrandsResponse>(cached);
                if (cachedResponse is not null)
                {
                    _logger.LogInformation(JsonSerializer.Serialize(new
                    {
                        timestamp = DateTimeOffset.UtcNow.ToString("o"),
                        traceId,
                        @event    = "CatalogBrandListCacheHit"
                    }));
                    return Results.Ok(cachedResponse);
                }
            }
        }
        catch (Exception ex)
        {
            // Cache read failure is non-fatal; fall through to DB.
            _logger.LogWarning(JsonSerializer.Serialize(new
            {
                timestamp = DateTimeOffset.UtcNow.ToString("o"),
                traceId,
                @event    = "CatalogBrandListCacheReadFailed",
                error     = ex.Message
            }));
        }

        var response = new ListCatalogBrandsResponse();
        var items    = await catalogBrandRepository.ListAsync();
        response.CatalogBrands.AddRange(items.Select(_mapper.Map<CatalogBrandDto>));

        // Populate cache best-effort.
        try
        {
            var serialized = JsonSerializer.Serialize(response);
            await _cache.SetStringAsync(CacheKey, serialized, new DistributedCacheEntryOptions
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
                @event    = "CatalogBrandListCacheWriteFailed",
                error     = ex.Message
            }));
        }

        _logger.LogInformation(JsonSerializer.Serialize(new
        {
            timestamp = DateTimeOffset.UtcNow.ToString("o"),
            traceId,
            @event    = "CatalogBrandListFetched",
            count     = response.CatalogBrands.Count
        }));

        return Results.Ok(response);
    }
}
