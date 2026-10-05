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

namespace Microsoft.eShopWeb.PublicApi.CatalogTypeEndpoints;

/// <summary>
/// List Catalog Types
/// </summary>
public class CatalogTypeListEndpoint : IEndpoint<IResult, IRepository<CatalogType>>
{
    private const int CacheTtlSeconds = 300;
    private readonly IMapper _mapper;
    private readonly IDistributedCache _cache;
    private readonly ILogger<CatalogTypeListEndpoint> _logger;

    public CatalogTypeListEndpoint(IMapper mapper, IDistributedCache cache, ILogger<CatalogTypeListEndpoint> logger)
    {
        _mapper = mapper;
        _cache = cache;
        _logger = logger;
    }

    public void AddRoute(IEndpointRouteBuilder app)
    {
        app.MapGet("api/v1/catalog-types",
            async (IRepository<CatalogType> catalogTypeRepository) =>
            {
                return await HandleAsync(catalogTypeRepository);
            })
            .Produces<ListCatalogTypesResponse>()
            .WithTags("CatalogTypeEndpoints")
            .RequireAuthorization();
    }

    public async Task<IResult> HandleAsync(IRepository<CatalogType> catalogTypeRepository)
    {
        var cacheKey = ComputeCacheKey("catalog-types:list");

        try
        {
            var cached = await _cache.GetStringAsync(cacheKey);
            if (cached != null)
            {
                _logger.LogInformation("Cache hit for catalog types list. CacheKey={CacheKey}", cacheKey);
                var cachedResponse = JsonSerializer.Deserialize<ListCatalogTypesResponse>(cached);
                if (cachedResponse != null)
                    return Results.Ok(cachedResponse);
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Redis cache read failed for catalog types list; falling through to DB.");
        }

        var response = new ListCatalogTypesResponse();
        var items = await catalogTypeRepository.ListAsync();
        response.CatalogTypes.AddRange(items.Select(_mapper.Map<CatalogTypeDto>));

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
            _logger.LogWarning(ex, "Redis cache write failed for catalog types list.");
        }

        return Results.Ok(response);
    }

    private static string ComputeCacheKey(string input)
    {
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(input));
        return Convert.ToHexString(hash).ToLowerInvariant();
    }
}
