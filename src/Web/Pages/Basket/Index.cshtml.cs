using Ardalis.GuardClauses;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.eShopWeb.ApplicationCore.Entities;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.eShopWeb.Web.Interfaces;
using Microsoft.eShopWeb.Web.ViewModels;

namespace Microsoft.eShopWeb.Web.Pages.Basket;

public class IndexModel : PageModel
{
    private readonly IBasketService _basketService;
    private readonly IBasketViewModelService _basketViewModelService;
    private readonly IRepository<CatalogItem> _itemRepository;
    private readonly ILogger<IndexModel> _logger;

    public IndexModel(
        IBasketService basketService,
        IBasketViewModelService basketViewModelService,
        IRepository<CatalogItem> itemRepository,
        ILogger<IndexModel> logger)
    {
        _basketService = basketService;
        _basketViewModelService = basketViewModelService;
        _itemRepository = itemRepository;
        _logger = logger;
    }

    public BasketViewModel BasketModel { get; set; } = new BasketViewModel();

    public async Task OnGet()
    {
        var userName = GetOrSetBasketCookieAndUserName();
        _logger.LogInformation("Basket Index GET for UserName={UserName}", userName);
        BasketModel = await _basketViewModelService.GetOrCreateBasketForUser(userName);
    }

    public async Task<IActionResult> OnPost(CatalogItemViewModel productDetails)
    {
        if (productDetails?.Id == null)
        {
            _logger.LogWarning("Basket OnPost: productDetails or Id is null");
            return RedirectToPage("/Index");
        }

        var item = await _itemRepository.GetByIdAsync(productDetails.Id);
        if (item == null)
        {
            _logger.LogWarning(
                "Basket OnPost: CatalogItem not found for Id={ItemId}", productDetails.Id);
            return RedirectToPage("/Index");
        }

        var username = GetOrSetBasketCookieAndUserName();
        _logger.LogInformation(
            "Basket OnPost: adding ItemId={ItemId} for UserName={UserName}",
            productDetails.Id, username);

        var basket = await _basketService.AddItemToBasket(username,
            productDetails.Id, item.Price);

        BasketModel = await _basketViewModelService.Map(basket);

        return RedirectToPage();
    }

    public async Task OnPostUpdate(IEnumerable<BasketItemViewModel> items)
    {
        if (!ModelState.IsValid)
        {
            _logger.LogWarning("Basket OnPostUpdate: invalid model state");
            return;
        }

        var userName = GetOrSetBasketCookieAndUserName();
        _logger.LogInformation(
            "Basket OnPostUpdate for UserName={UserName}", userName);

        var basketView = await _basketViewModelService.GetOrCreateBasketForUser(userName);
        var updateModel = items.ToDictionary(b => b.Id.ToString(), b => b.Quantity);
        var basket = await _basketService.SetQuantities(basketView.Id, updateModel);
        BasketModel = await _basketViewModelService.Map(basket);
    }

    private string GetOrSetBasketCookieAndUserName()
    {
        Guard.Against.Null(
            Request.HttpContext.User.Identity,
            nameof(Request.HttpContext.User.Identity));

        string? userName = null;

        if (Request.HttpContext.User.Identity.IsAuthenticated)
        {
            Guard.Against.Null(
                Request.HttpContext.User.Identity.Name,
                nameof(Request.HttpContext.User.Identity.Name));
            return Request.HttpContext.User.Identity.Name!;
        }

        if (Request.Cookies.ContainsKey(Constants.BASKET_COOKIENAME))
        {
            userName = Request.Cookies[Constants.BASKET_COOKIENAME];

            if (!Guid.TryParse(userName, out _))
            {
                userName = null;
            }
        }

        if (userName != null) return userName;

        userName = Guid.NewGuid().ToString();
        var cookieOptions = new CookieOptions
        {
            IsEssential = true,
            Expires = DateTime.Today.AddYears(10),
            HttpOnly = true,
            Secure = true,
            SameSite = SameSiteMode.Lax
        };
        Response.Cookies.Append(Constants.BASKET_COOKIENAME, userName, cookieOptions);

        return userName;
    }
}
