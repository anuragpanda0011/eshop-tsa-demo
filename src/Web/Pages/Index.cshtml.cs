using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.eShopWeb.Web.Services;
using Microsoft.eShopWeb.Web.ViewModels;

namespace Microsoft.eShopWeb.Web.Pages;

public class IndexModel : PageModel
{
    private readonly ICatalogViewModelService _catalogViewModelService;
    private readonly ILogger<IndexModel> _logger;

    public IndexModel(
        ICatalogViewModelService catalogViewModelService,
        ILogger<IndexModel> logger)
    {
        _catalogViewModelService = catalogViewModelService;
        _logger = logger;
    }

    public required CatalogIndexViewModel CatalogModel { get; set; } = new CatalogIndexViewModel();

    public async Task OnGet(CatalogIndexViewModel catalogModel, int? pageId)
    {
        _logger.LogInformation(
            "Catalog Index GET pageId={PageId} brandId={BrandId} typeId={TypeId}",
            pageId,
            catalogModel.BrandFilterApplied,
            catalogModel.TypesFilterApplied);

        CatalogModel = await _catalogViewModelService.GetCatalogItems(
            pageId ?? 0,
            Constants.ITEMS_PER_PAGE,
            catalogModel.BrandFilterApplied,
            catalogModel.TypesFilterApplied);
    }
}
