using Ardalis.GuardClauses;
using Azure.Messaging.ServiceBus;
using Microsoft.eShopWeb.ApplicationCore.Entities;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.eShopWeb.Web.Interfaces;
using Microsoft.eShopWeb.Web.ViewModels;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Caching.Distributed;

namespace Microsoft.eShopWeb.Web.Services;

public class CatalogItemViewModelService : ICatalogItemViewModelService
{
    private readonly IRepository<CatalogItem> _catalogItemRepository;
    private readonly ILogger<CatalogItemViewModelService> _logger;
    private readonly ServiceBusClient _serviceBusClient;
    private readonly IConfiguration _configuration;
    private readonly IDistributedCache _cache;

    public CatalogItemViewModelService(
        IRepository<CatalogItem> catalogItemRepository,
        ILogger<CatalogItemViewModelService> logger,
        ServiceBusClient serviceBusClient,
        IConfiguration configuration,
        IDistributedCache cache)
    {
        _catalogItemRepository = catalogItemRepository;
        _logger = logger;
        _serviceBusClient = serviceBusClient;
        _configuration = configuration;
        _cache = cache;
    }

    public async Task UpdateCatalogItem(CatalogItemViewModel viewModel)
    {
        _logger.LogInformation(
            "UpdateCatalogItem called for ItemId={ItemId} Name={Name} Price={Price}",
            viewModel.Id, viewModel.Name, viewModel.Price);

        var existingCatalogItem = await _catalogItemRepository.GetByIdAsync(viewModel.Id);
        Guard.Against.Null(existingCatalogItem, nameof(existingCatalogItem));

        CatalogItem.CatalogItemDetails details = new(
            viewModel.Name,
            existingCatalogItem.Description,
            viewModel.Price);

        existingCatalogItem.UpdateDetails(details);
        await _catalogItemRepository.UpdateAsync(existingCatalogItem);

        _logger.LogInformation(
            "UpdateCatalogItem succeeded for ItemId={ItemId}", viewModel.Id);

        // Invalidate Redis cache entries that relate to catalog items
        await InvalidateCatalogCacheAsync();

        // Publish state-change event (best-effort)
        await PublishCatalogItemUpdatedEventAsync(viewModel);
    }

    private async Task InvalidateCatalogCacheAsync()
    {
        // Remove well-known cache keys by hashing their raw keys
        // (mirrors the hashing strategy in CachedCatalogViewModelService)
        var keysToInvalidate = new[]
        {
            Extensions.CacheHelpers.GenerateBrandsCacheKey(),
            Extensions.CacheHelpers.GenerateTypesCacheKey()
        };

        foreach (var rawKey in keysToInvalidate)
        {
            try
            {
                var hashedKey = HashKey(rawKey);
                await _cache.RemoveAsync(hashedKey);
                _logger.LogDebug("Cache invalidated for key={RawKey}", rawKey);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex,
                    "Failed to invalidate cache for key={RawKey}", rawKey);
            }
        }
    }

    private static string HashKey(string rawKey)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(rawKey));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }

    private async Task PublishCatalogItemUpdatedEventAsync(CatalogItemViewModel viewModel)
    {
        try
        {
            var topicName = _configuration["ServiceBus:CatalogItemUpdatedTopic"]
                ?? "catalog-item-updated";
            var sender = _serviceBusClient.CreateSender(topicName);

            var payload = new
            {
                EventType = "CatalogItemUpdated",
                OccurredAt = DateTimeOffset.UtcNow,
                ItemId = viewModel.Id,
                Name = viewModel.Name,
                Price = viewModel.Price,
                PictureUri = viewModel.PictureUri
            };

            var messageBody = JsonSerializer.Serialize(payload);
            var message = new ServiceBusMessage(messageBody)
            {
                ContentType = "application/json",
                Subject = "CatalogItemUpdated"
            };

            await sender.SendMessageAsync(message);

            _logger.LogInformation(
                "Published CatalogItemUpdated event for ItemId={ItemId}", viewModel.Id);
        }
        catch (Exception ex)
        {
            // Best-effort: log but do not rethrow
            _logger.LogWarning(ex,
                "Failed to publish CatalogItemUpdated event for ItemId={ItemId}",
                viewModel.Id);
        }
    }
}
