using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.eShopWeb.Web.Interfaces;
using Microsoft.eShopWeb.Web.ViewModels;

namespace Microsoft.eShopWeb.Web.Pages.Admin;

[Authorize(Roles = BlazorShared.Authorization.Constants.Roles.ADMINISTRATORS)]
public class EditCatalogItemModel : PageModel
{
    private readonly ICatalogItemViewModelService _catalogItemViewModelService;
    private readonly ILogger<EditCatalogItemModel> _logger;

    public EditCatalogItemModel(
        ICatalogItemViewModelService catalogItemViewModelService,
        ILogger<EditCatalogItemModel> logger)
    {
        _catalogItemViewModelService = catalogItemViewModelService;
        _logger = logger;
    }

    [BindProperty]
    public CatalogItemViewModel CatalogModel { get; set; } = new CatalogItemViewModel();

    public void OnGet(CatalogItemViewModel catalogModel)
    {
        CatalogModel = catalogModel;
        _logger.LogInformation(
            "Admin EditCatalogItem GET for ItemId={ItemId} by User={User}",
            catalogModel.Id,
            User?.Identity?.Name);
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid)
        {
            _logger.LogWarning(
                "Admin EditCatalogItem POST invalid model for ItemId={ItemId} by User={User}",
                CatalogModel.Id,
                User?.Identity?.Name);
            return Page();
        }

        _logger.LogInformation(
            "Admin EditCatalogItem POST updating ItemId={ItemId} by User={User}",
            CatalogModel.Id,
            User?.Identity?.Name);

        await _catalogItemViewModelService.UpdateCatalogItem(CatalogModel);

        _logger.LogInformation(
            "Admin EditCatalogItem POST updated ItemId={ItemId} successfully",
            CatalogModel.Id);

        return RedirectToPage("/Admin/Index");
    }
}
