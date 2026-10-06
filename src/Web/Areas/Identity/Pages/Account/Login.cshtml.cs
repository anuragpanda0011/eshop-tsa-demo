using System.ComponentModel.DataAnnotations;
using System.Threading.Tasks;
using Ardalis.GuardClauses;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.eShopWeb.Infrastructure.Identity;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.Web.Areas.Identity.Pages.Account;

[AllowAnonymous]
public class LoginModel : PageModel
{
    private readonly SignInManager<ApplicationUser> _signInManager;
    private readonly ILogger<LoginModel> _logger;
    private readonly IBasketService _basketService;
    private readonly IDistributedCache _distributedCache;

    public LoginModel(
        SignInManager<ApplicationUser> signInManager,
        ILogger<LoginModel> logger,
        IBasketService basketService,
        IDistributedCache distributedCache)
    {
        _signInManager = signInManager;
        _logger = logger;
        _basketService = basketService;
        _distributedCache = distributedCache;
    }

    [BindProperty]
    public required InputModel Input { get; set; }

    public IList<AuthenticationScheme>? ExternalLogins { get; set; }

    public string? ReturnUrl { get; set; }

    [TempData]
    public string? ErrorMessage { get; set; }

    public class InputModel
    {
        [Required]
        [EmailAddress]
        public string? Email { get; set; }

        [Required]
        [DataType(DataType.Password)]
        public string? Password { get; set; }

        [Display(Name = "Remember me?")]
        public bool RememberMe { get; set; }
    }

    public async Task OnGetAsync(string? returnUrl = null)
    {
        if (!string.IsNullOrEmpty(ErrorMessage))
        {
            ModelState.AddModelError(string.Empty, ErrorMessage);
        }

        returnUrl = returnUrl ?? Url.Content("~/");

        // Clear the existing external cookie to ensure a clean login process
        await HttpContext.SignOutAsync(IdentityConstants.ExternalScheme);

        ExternalLogins = (await _signInManager.GetExternalAuthenticationSchemesAsync()).ToList();

        ReturnUrl = returnUrl;
    }

    public async Task<IActionResult> OnPostAsync(string? returnUrl = null)
    {
        returnUrl = returnUrl ?? Url.Content("~/");

        // Rate-limit check via distributed cache (Redis-backed)
        var rateLimitKey = $"login_ratelimit:{HashHelper.HashKey(Input?.Email ?? HttpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown")}";
        var attemptBytes = await _distributedCache.GetAsync(rateLimitKey);
        int attempts = attemptBytes != null ? int.Parse(System.Text.Encoding.UTF8.GetString(attemptBytes)) : 0;

        if (attempts >= 10)
        {
            _logger.LogWarning("Login rate limit exceeded for key. TraceId={TraceId}", HttpContext.TraceIdentifier);
            ModelState.AddModelError(string.Empty, "Too many login attempts. Please try again later.");
            return Page();
        }

        if (ModelState.IsValid)
        {
            var result = await _signInManager.PasswordSignInAsync(
                Input!.Email!, Input!.Password!, false, lockoutOnFailure: true);

            if (result.Succeeded)
            {
                _logger.LogInformation("User logged in. TraceId={TraceId}", HttpContext.TraceIdentifier);
                // Reset rate-limit on success
                await _distributedCache.RemoveAsync(rateLimitKey);
                await TransferAnonymousBasketToUserAsync(Input?.Email);
                return LocalRedirect(returnUrl);
            }

            // Increment rate-limit counter on failure
            attempts++;
            await _distributedCache.SetAsync(
                rateLimitKey,
                System.Text.Encoding.UTF8.GetBytes(attempts.ToString()),
                new DistributedCacheEntryOptions
                {
                    AbsoluteExpirationRelativeToNow = System.TimeSpan.FromMinutes(15)
                });

            if (result.RequiresTwoFactor)
            {
                return RedirectToPage("./LoginWith2fa", new { ReturnUrl = returnUrl, RememberMe = Input?.RememberMe });
            }
            if (result.IsLockedOut)
            {
                _logger.LogWarning("User account locked out. TraceId={TraceId}", HttpContext.TraceIdentifier);
                return RedirectToPage("./Lockout");
            }
            else
            {
                ModelState.AddModelError(string.Empty, "Invalid login attempt.");
                return Page();
            }
        }

        // If we got this far, something failed, redisplay form
        return Page();
    }

    private async Task TransferAnonymousBasketToUserAsync(string? userName)
    {
        if (Request.Cookies.ContainsKey(Constants.BASKET_COOKIENAME))
        {
            var anonymousId = Request.Cookies[Constants.BASKET_COOKIENAME];
            if (Guid.TryParse(anonymousId, out var _))
            {
                Guard.Against.NullOrEmpty(userName, nameof(userName));
                await _basketService.TransferBasketAsync(anonymousId!, userName);
            }
            Response.Cookies.Delete(Constants.BASKET_COOKIENAME);
        }
    }
}
