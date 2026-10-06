using Ardalis.GuardClauses;
using Microsoft.eShopWeb.ApplicationCore.Entities;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.eShopWeb.Web.Interfaces;
using Microsoft.eShopWeb.Web.ViewModels;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.Web.Services;

public class CatalogItemViewModelService : ICatalogItemViewModelService
{
    private readonly IRepository<CatalogItem> _catalogItemRepository;
    private readonly ILogger<CatalogItemViewModelService> _logger;

    public CatalogItemViewModelService(
        IRepository<CatalogItem> catalogItemRepository,
        ILogger<CatalogItemViewModelService> logger)
    {
        _catalogItemRepository = catalogItemRepository;
        _logger = logger;
    }

    public async Task UpdateCatalogItem(CatalogItemViewModel viewModel)
    {
        var existingCatalogItem = await _catalogItemRepository.GetByIdAsync(viewModel.Id);

        Guard.Against.Null(existingCatalogItem, nameof(existingCatalogItem));

        CatalogItem.CatalogItemDetails details = new(
            viewModel.Name,
            existingCatalogItem.Description,
            viewModel.Price);

        existingCatalogItem.UpdateDetails(details);
        await _catalogItemRepository.UpdateAsync(existingCatalogItem);

        _logger.LogInformation(
            "{{\"event\":\"CatalogItemUpdated\",\"catalogItemId\":{CatalogItemId},\"name\":\"{Name}\"}}",
            viewModel.Id, viewModel.Name);
    }
}
