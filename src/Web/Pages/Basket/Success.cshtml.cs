using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Microsoft.eShopWeb.Web.Pages.Basket;

[Authorize]
public class SuccessModel : PageModel
{
    private readonly ILogger<SuccessModel> _logger;

    public SuccessModel(ILogger<SuccessModel> logger)
    {
        _logger = logger;
    }

    public void OnGet()
    {
        _logger.LogInformation(
            "Order success page accessed by User={User}",
            User?.Identity?.Name);
    }
}
