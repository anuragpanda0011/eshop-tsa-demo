using System.Text.Json;
using System.Threading.Tasks;
using Azure.Messaging.ServiceBus;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.eShopWeb.Web.Interfaces;
using Microsoft.eShopWeb.Web.ViewModels;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.Web.Pages.Admin;

[Authorize(Roles = BlazorShared.Authorization.Constants.Roles.ADMINISTRATORS)]
public class EditCatalogItemModel : PageModel
{
    private readonly ICatalogItemViewModelService _catalogItemViewModelService;
    private readonly ILogger<EditCatalogItemModel> _logger;
    private readonly ServiceBusClient? _serviceBusClient;
    private readonly string _eventsTopic;

    public EditCatalogItemModel(
        ICatalogItemViewModelService catalogItemViewModelService,
        ILogger<EditCatalogItemModel> logger,
        ServiceBusClient? serviceBusClient = null)
    {
        _catalogItemViewModelService = catalogItemViewModelService;
        _logger = logger;
        _serviceBusClient = serviceBusClient;
        _eventsTopic = Environment.GetEnvironmentVariable("SERVICEBUS_EVENTS_TOPIC") ?? "catalog-events";
    }

    [BindProperty]
    public CatalogItemViewModel CatalogModel { get; set; } = new CatalogItemViewModel();

    public void OnGet(CatalogItemViewModel catalogModel)
    {
        CatalogModel = catalogModel;
    }

    public async Task<IActionResult> OnPostAsync()
    {
        if (!ModelState.IsValid)
        {
            return Page();
        }

        await _catalogItemViewModelService.UpdateCatalogItem(CatalogModel);

        _logger.LogInformation(
            "Admin user '{Admin}' updated catalog item '{ItemId}' at {UpdatedAt}.",
            User.Identity?.Name,
            CatalogModel.Id,
            DateTimeOffset.UtcNow);

        await PublishEventAsync("CatalogItemUpdated", new
        {
            CatalogModel.Id,
            CatalogModel.Name,
            UpdatedBy = User.Identity?.Name,
            UpdatedAt = DateTimeOffset.UtcNow
        });

        return RedirectToPage("/Admin/Index");
    }

    private async Task PublishEventAsync(string eventType, object payload)
    {
        if (_serviceBusClient == null) return;
        try
        {
            var sender = _serviceBusClient.CreateSender(_eventsTopic);
            var body = JsonSerializer.Serialize(new
            {
                EventType = eventType,
                OccurredAt = DateTimeOffset.UtcNow,
                Payload = payload
            });
            var message = new ServiceBusMessage(body)
            {
                ContentType = "application/json",
                Subject = eventType
            };
            await sender.SendMessageAsync(message);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(
                "Failed to publish event '{EventType}' to Service Bus: {Error}",
                eventType,
                ex.Message);
        }
    }
}
