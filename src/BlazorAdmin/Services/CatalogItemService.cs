using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using BlazorShared.Interfaces;
using BlazorShared.Models;
using Microsoft.Extensions.Logging;

namespace BlazorAdmin.Services;

public class CatalogItemService : ICatalogItemService
{
    private readonly ICatalogLookupDataService<CatalogBrand> _brandService;
    private readonly ICatalogLookupDataService<CatalogType> _typeService;
    private readonly HttpService _httpService;
    private readonly ILogger<CatalogItemService> _logger;

    public CatalogItemService(
        ICatalogLookupDataService<CatalogBrand> brandService,
        ICatalogLookupDataService<CatalogType> typeService,
        HttpService httpService,
        ILogger<CatalogItemService> logger)
    {
        _brandService = brandService;
        _typeService = typeService;
        _httpService = httpService;
        _logger = logger;
    }

    public async Task<CatalogItem> Create(CreateCatalogItemRequest catalogItem)
    {
        var response = await _httpService.HttpPost<CreateCatalogItemResponse>(
            "catalog-items", catalogItem);
        return response?.CatalogItem;
    }

    public async Task<CatalogItem> Edit(CatalogItem catalogItem)
    {
        var result = await _httpService.HttpPut<EditCatalogItemResult>(
            "catalog-items", catalogItem);
        return result?.CatalogItem;
    }

    public async Task<string> Delete(int catalogItemId)
    {
        var result = await _httpService.HttpDelete<DeleteCatalogItemResponse>(
            "catalog-items", catalogItemId);
        return result?.Status;
    }

    public async Task<CatalogItem> GetById(int id)
    {
        var brandListTask = _brandService.List();
        var typeListTask = _typeService.List();
        var itemGetTask = _httpService.HttpGet<EditCatalogItemResult>($"catalog-items/{id}");
        await Task.WhenAll(brandListTask, typeListTask, itemGetTask);

        var brands = brandListTask.Result;
        var types = typeListTask.Result;
        var catalogItem = itemGetTask.Result?.CatalogItem;
        if (catalogItem == null) return null;

        catalogItem.CatalogBrand =
            brands.FirstOrDefault(b => b.Id == catalogItem.CatalogBrandId)?.Name;
        catalogItem.CatalogType =
            types.FirstOrDefault(t => t.Id == catalogItem.CatalogTypeId)?.Name;
        return catalogItem;
    }

    public async Task<List<CatalogItem>> ListPaged(int pageSize)
    {
        _logger.LogInformation(
            "{{\"event\":\"list_paged\",\"pageSize\":{PageSize}}}",
            pageSize);

        var brandListTask = _brandService.List();
        var typeListTask = _typeService.List();
        var itemListTask = _httpService.HttpGet<PagedCatalogItemResponse>(
            $"catalog-items?PageSize={pageSize}");
        await Task.WhenAll(brandListTask, typeListTask, itemListTask);

        var brands = brandListTask.Result;
        var types = typeListTask.Result;
        var items = itemListTask.Result?.CatalogItems ?? new List<CatalogItem>();
        EnrichItems(items, brands, types);
        return items;
    }

    public async Task<List<CatalogItem>> List()
    {
        _logger.LogInformation("{{\"event\":\"list_all\",\"message\":\"Fetching catalog items from API.\"}}");

        var brandListTask = _brandService.List();
        var typeListTask = _typeService.List();
        var itemListTask = _httpService.HttpGet<PagedCatalogItemResponse>("catalog-items");
        await Task.WhenAll(brandListTask, typeListTask, itemListTask);

        var brands = brandListTask.Result;
        var types = typeListTask.Result;
        var items = itemListTask.Result?.CatalogItems ?? new List<CatalogItem>();
        EnrichItems(items, brands, types);
        return items;
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    private static void EnrichItems(
        List<CatalogItem> items,
        List<CatalogBrand> brands,
        List<CatalogType> types)
    {
        foreach (var item in items)
        {
            item.CatalogBrand =
                brands.FirstOrDefault(b => b.Id == item.CatalogBrandId)?.Name;
            item.CatalogType =
                types.FirstOrDefault(t => t.Id == item.CatalogTypeId)?.Name;
        }
    }
}
