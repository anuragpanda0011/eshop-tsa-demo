using Ardalis.GuardClauses;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.eShopWeb.Infrastructure.Identity;
using Microsoft.eShopWeb.Web.Interfaces;
using Microsoft.eShopWeb.Web.ViewModels;

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
        var vm = new BasketComponentViewModel
        {
            ItemsCount = await CountTotalBasketItems()
        };
        return View(vm);
    }

    private async Task<int> CountTotalBasketItems()
    {
        if (_signInManager.IsSignedIn(HttpContext.User))
        {
            Guard.Against.Null(User?.Identity?.Name, nameof(User.Identity.Name));
            _logger.LogDebug(
                "CountTotalBasketItems for authenticated user={User}",
                User.Identity.Name);
            return await _basketService.CountTotalBasketItems(User.Identity.Name);
        }

        string? anonymousId = GetAnonymousIdFromCookie();
        if (anonymousId == null)
        {
            _logger.LogDebug("CountTotalBasketItems: no anonymous basket cookie found");
            return 0;
        }

        _logger.LogDebug(
            "CountTotalBasketItems for anonymous basket id={AnonymousId}", anonymousId);
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
