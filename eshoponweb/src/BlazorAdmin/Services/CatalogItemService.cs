using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
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
        _logger.LogInformation("{\"event\":\"catalog_item_create\",\"name\":\"{Name}\"}",
            catalogItem?.Name);

        var response = await _httpService.HttpPost<CreateCatalogItemResponse>("catalog-items", catalogItem);
        return response?.CatalogItem;
    }

    public async Task<CatalogItem> Edit(CatalogItem catalogItem)
    {
        _logger.LogInformation("{\"event\":\"catalog_item_edit\",\"id\":{Id}}", catalogItem?.Id);

        var result = await _httpService.HttpPut<EditCatalogItemResult>("catalog-items", catalogItem);
        return result?.CatalogItem;
    }

    public async Task<string> Delete(int catalogItemId)
    {
        _logger.LogInformation("{\"event\":\"catalog_item_delete\",\"id\":{Id}}", catalogItemId);

        var result = await _httpService.HttpDelete<DeleteCatalogItemResponse>("catalog-items", catalogItemId);
        return result?.Status;
    }

    public async Task<CatalogItem> GetById(int id)
    {
        _logger.LogInformation("{\"event\":\"catalog_item_get\",\"id\":{Id}}", id);

        var brandListTask = _brandService.List();
        var typeListTask = _typeService.List();
        var itemGetTask = _httpService.HttpGet<EditCatalogItemResult>($"catalog-items/{id}");

        await Task.WhenAll(brandListTask, typeListTask, itemGetTask);

        var brands = brandListTask.Result;
        var types = typeListTask.Result;
        var catalogItem = itemGetTask.Result?.CatalogItem;

        if (catalogItem == null)
        {
            _logger.LogWarning("{\"event\":\"catalog_item_not_found\",\"id\":{Id}}", id);
            return null;
        }

        catalogItem.CatalogBrand = brands?.FirstOrDefault(b => b.Id == catalogItem.CatalogBrandId)?.Name;
        catalogItem.CatalogType = types?.FirstOrDefault(t => t.Id == catalogItem.CatalogTypeId)?.Name;

        return catalogItem;
    }

    public async Task<List<CatalogItem>> ListPaged(int pageSize)
    {
        _logger.LogInformation(
            "{\"event\":\"catalog_items_list_paged\",\"pageSize\":{PageSize}}",
            pageSize);

        var brandListTask = _brandService.List();
        var typeListTask = _typeService.List();
        var itemListTask = _httpService.HttpGet<PagedCatalogItemResponse>(
            $"catalog-items?PageSize={pageSize}");

        await Task.WhenAll(brandListTask, typeListTask, itemListTask);

        var brands = brandListTask.Result ?? new List<CatalogBrand>();
        var types = typeListTask.Result ?? new List<CatalogType>();
        var items = itemListTask.Result?.CatalogItems ?? new List<CatalogItem>();

        foreach (var item in items)
        {
            item.CatalogBrand = brands.FirstOrDefault(b => b.Id == item.CatalogBrandId)?.Name;
            item.CatalogType = types.FirstOrDefault(t => t.Id == item.CatalogTypeId)?.Name;
        }

        return items;
    }

    public async Task<List<CatalogItem>> List()
    {
        _logger.LogInformation("{\"event\":\"catalog_items_list\"}");

        var brandListTask = _brandService.List();
        var typeListTask = _typeService.List();
        var itemListTask = _httpService.HttpGet<PagedCatalogItemResponse>("catalog-items");

        await Task.WhenAll(brandListTask, typeListTask, itemListTask);

        var brands = brandListTask.Result ?? new List<CatalogBrand>();
        var types = typeListTask.Result ?? new List<CatalogType>();
        var items = itemListTask.Result?.CatalogItems ?? new List<CatalogItem>();

        foreach (var item in items)
        {
            item.CatalogBrand = brands.FirstOrDefault(b => b.Id == item.CatalogBrandId)?.Name;
            item.CatalogType = types.FirstOrDefault(t => t.Id == item.CatalogTypeId)?.Name;
        }

        return items;
    }
}
