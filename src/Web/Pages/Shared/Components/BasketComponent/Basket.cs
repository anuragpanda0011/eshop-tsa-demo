using System;
using System.Threading.Tasks;
using Ardalis.GuardClauses;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.eShopWeb.Infrastructure.Identity;
using Microsoft.eShopWeb.Web.Interfaces;
using Microsoft.eShopWeb.Web.ViewModels;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.Web.Pages.Shared.Components.BasketComponent;

public class Basket : ViewComponent
{
    private readonly IBasketViewModelService _basketService;
    private readonly SignInManager<ApplicationUser> _signInManager;
    private readonly ILogger<Basket> _logger;

    public Basket(
        IBasketViewModelService basketService,
        SignInManager<ApplicationUser> signInManager,
        ILogger<Basket> logger)
    {
        _basketService = basketService;
        _signInManager = signInManager;
        _logger = logger;
    }

    public async Task<IViewComponentResult> InvokeAsync()
    {
        var traceId = HttpContext.TraceIdentifier;

        var vm = new BasketComponentViewModel
        {
            ItemsCount = await CountTotalBasketItems()
        };

        _logger.LogInformation(
            "{{\"event\":\"BasketComponent.Invoked\",\"itemsCount\":{ItemsCount},\"traceId\":\"{TraceId}\"}}",
            vm.ItemsCount, traceId);

        return View(vm);
    }

    private async Task<int> CountTotalBasketItems()
    {
        if (_signInManager.IsSignedIn(HttpContext.User))
        {
            Guard.Against.Null(User?.Identity?.Name, nameof(User.Identity.Name));
            return await _basketService.CountTotalBasketItems(User.Identity.Name);
        }

        string? anonymousId = GetAnonymousIdFromCookie();
        if (anonymousId == null)
            return 0;

        return await _basketService.CountTotalBasketItems(anonymousId);
    }

    private string? GetAnonymousIdFromCookie()
    {
        if (Request.Cookies.ContainsKey(Constants.BASKET_COOKIENAME))
        {
            var id = Request.Cookies[Constants.BASKET_COOKIENAME];

            if (Guid.TryParse(id, out _))
            {
                return id;
            }
        }
        return null;
    }
}
