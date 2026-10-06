using System;
using System.Linq;
using System.Security.Claims;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.eShopWeb.Infrastructure.Identity;
using Microsoft.eShopWeb.Web.Configuration;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.Web.Areas.Identity.Pages.Account;

public class LogoutModel : PageModel
{
    private readonly SignInManager<ApplicationUser> _signInManager;
    private readonly ILogger<LogoutModel> _logger;
    private readonly IDistributedCache _cache;

    public LogoutModel(
        SignInManager<ApplicationUser> signInManager,
        ILogger<LogoutModel> logger,
        IDistributedCache cache)
    {
        _signInManager = signInManager;
        _logger = logger;
        _cache = cache;
    }

    public void OnGet()
    {
    }

    public async Task<IActionResult> OnPost(string? returnUrl = null)
    {
        await _signInManager.SignOutAsync();
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);

        var userId = _signInManager.Context.User.Claims.FirstOrDefault(c => c.Type == ClaimTypes.Name);
        var identityKey = _signInManager.Context.Request.Cookies[ConfigureCookieSettings.IdentifierCookieName];

        if (userId != null && identityKey != null)
        {
            var cacheKey = HashHelper.HashKey($"{userId.Value}:{identityKey}");
            await _cache.SetAsync(
                cacheKey,
                Encoding.UTF8.GetBytes(identityKey),
                new DistributedCacheEntryOptions
                {
                    AbsoluteExpiration = DateTimeOffset.UtcNow.AddMinutes(ConfigureCookieSettings.ValidityMinutesPeriod)
                });
        }

        _logger.LogInformation("User logged out. TraceId={TraceId}", HttpContext.TraceIdentifier);

        if (returnUrl != null)
        {
            return LocalRedirect(returnUrl);
        }
        else
        {
            return RedirectToPage("/Index");
        }
    }
}
