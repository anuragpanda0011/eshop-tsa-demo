using System.Collections.Generic;
using System.Threading.Tasks;
using BlazorAdmin.Helpers;
using BlazorShared.Interfaces;
using BlazorShared.Models;

namespace BlazorAdmin.Pages.CatalogItemPage;

public partial class List : BlazorComponent
{
    [Microsoft.AspNetCore.Components.Inject]
    public ICatalogItemService CatalogItemService { get; set; } = default!;

    [Microsoft.AspNetCore.Components.Inject]
    public ICatalogLookupDataService<CatalogBrand> CatalogBrandService { get; set; } = default!;

    [Microsoft.AspNetCore.Components.Inject]
    public ICatalogLookupDataService<CatalogType> CatalogTypeService { get; set; } = default!;

    private List<CatalogItem>  catalogItems = new();
    private List<CatalogType>  catalogTypes = new();
    private List<CatalogBrand> catalogBrands = new();

    private Edit    EditComponent    { get; set; } = default!;
    private Delete  DeleteComponent  { get; set; } = default!;
    private Details DetailsComponent { get; set; } = default!;
    private Create  CreateComponent  { get; set; } = default!;

    protected override async Task OnAfterRenderAsync(bool firstRender)
    {
        if (firstRender)
        {
            catalogItems  = await CatalogItemService.List();
            catalogTypes  = await CatalogTypeService.List();
            catalogBrands = await CatalogBrandService.List();

            CallRequestRefresh();
        }

        await base.OnAfterRenderAsync(firstRender);
    }

    private async void DetailsClick(int id)
    {
        await DetailsComponent.Open(id);
    }

    private async Task CreateClick()
    {
        await CreateComponent.Open();
    }

    private async Task EditClick(int id)
    {
        await EditComponent.Open(id);
    }

    private async Task DeleteClick(int id)
    {
        await DeleteComponent.Open(id);
    }

    private async Task ReloadCatalogItems()
    {
        catalogItems = await CatalogItemService.List();
        StateHasChanged();
    }
}
