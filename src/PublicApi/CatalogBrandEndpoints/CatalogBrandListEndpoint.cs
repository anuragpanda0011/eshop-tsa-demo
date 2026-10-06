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
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Logging;
using MinimalApi.Endpoint;

namespace Microsoft.eShopWeb.PublicApi.CatalogBrandEndpoints;

/// <summary>
/// List Catalog Brands
/// </summary>
public class CatalogBrandListEndpoint : IEndpoint<IResult, IRepository<CatalogBrand>>
{
    private readonly IMapper _mapper;
    private readonly IDistributedCache _cache;
    private readonly ILogger<CatalogBrandListEndpoint> _logger;
    private const int CacheTtlSeconds = 300;

    public CatalogBrandListEndpoint(IMapper mapper, IDistributedCache cache, ILogger<CatalogBrandListEndpoint> logger)
    {
        _mapper = mapper;
        _cache = cache;
        _logger = logger;
    }

    public void AddRoute(IEndpointRouteBuilder app)
    {
        app.MapGet("api/v1/catalog-brands",
            async (IRepository<CatalogBrand> catalogBrandRepository, HttpContext httpContext) =>
            {
                return await HandleAsync(catalogBrandRepository);
            })
           .Produces<ListCatalogBrandsResponse>()
           .WithTags("CatalogBrandEndpoints");
    }

    public async Task<IResult> HandleAsync(IRepository<CatalogBrand> catalogBrandRepository)
    {
        var cacheKey = ComputeCacheKey("catalog-brands:all");

        try
        {
            var cached = await _cache.GetStringAsync(cacheKey);
            if (cached is not null)
            {
                _logger.LogInformation("{Timestamp} Event=CacheHit Key={Key}", DateTimeOffset.UtcNow, cacheKey);
                var cachedResponse = JsonSerializer.Deserialize<ListCatalogBrandsResponse>(cached);
                return Results.Ok(cachedResponse);
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "{Timestamp} Event=CacheReadError Key={Key}", DateTimeOffset.UtcNow, cacheKey);
        }

        var response = new ListCatalogBrandsResponse();
        var items = await catalogBrandRepository.ListAsync();
        response.CatalogBrands.AddRange(items.Select(_mapper.Map<CatalogBrandDto>));

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
