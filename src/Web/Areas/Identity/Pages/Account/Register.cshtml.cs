using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Text.Encodings.Web;
using System.Threading.Tasks;
using Ardalis.GuardClauses;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.UI.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.eShopWeb.Infrastructure.Identity;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.Web.Areas.Identity.Pages.Account;

[AllowAnonymous]
public class RegisterModel : PageModel
{
    private readonly SignInManager<ApplicationUser> _signInManager;
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly ILogger<RegisterModel> _logger;
    private readonly IEmailSender _emailSender;
    private readonly IDistributedCache _distributedCache;

    public RegisterModel(
        UserManager<ApplicationUser> userManager,
        SignInManager<ApplicationUser> signInManager,
        ILogger<RegisterModel> logger,
        IEmailSender emailSender,
        IDistributedCache distributedCache)
    {
        _userManager = userManager;
        _signInManager = signInManager;
        _logger = logger;
        _emailSender = emailSender;
        _distributedCache = distributedCache;
    }

    [BindProperty]
    public required InputModel Input { get; set; }

    public string? ReturnUrl { get; set; }

    public class InputModel
    {
        [Required]
        [EmailAddress]
        [Display(Name = "Email")]
        public string? Email { get; set; }

        [Required]
        [StringLength(100, ErrorMessage = "The {0} must be at least {2} and at max {1} characters long.", MinimumLength = 6)]
        [DataType(DataType.Password)]
        [Display(Name = "Password")]
        public string? Password { get; set; }

        [DataType(DataType.Password)]
        [Display(Name = "Confirm password")]
        [Compare("Password", ErrorMessage = "The password and confirmation password do not match.")]
        public string? ConfirmPassword { get; set; }
    }

    public void OnGet(string? returnUrl = null)
    {
        ReturnUrl = returnUrl;
    }

    public async Task<IActionResult> OnPostAsync(string? returnUrl = null)
    {
        returnUrl = returnUrl ?? Url.Content("~/");

        // Rate-limit registration attempts by IP
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";
        var rateLimitKey = $"register_ratelimit:{HashHelper.HashKey(ipAddress)}";
        var attemptBytes = await _distributedCache.GetAsync(rateLimitKey);
        int attempts = attemptBytes != null ? int.Parse(System.Text.Encoding.UTF8.GetString(attemptBytes)) : 0;

        if (attempts >= 5)
        {
            _logger.LogWarning("Register rate limit exceeded. IP={IP} TraceId={TraceId}",
                ipAddress, HttpContext.TraceIdentifier);
            ModelState.AddModelError(string.Empty, "Too many registration attempts. Please try again later.");
            return Page();
        }

        if (ModelState.IsValid)
        {
            var user = new ApplicationUser { UserName = Input?.Email, Email = Input?.Email };
            var result = await _userManager.CreateAsync(user, Input?.Password!);
            if (result.Succeeded)
            {
                _logger.LogInformation("User created a new account with password. TraceId={TraceId}",
                    HttpContext.TraceIdentifier);

                // Reset rate limit on success
                await _distributedCache.RemoveAsync(rateLimitKey);

                var code = await _userManager.GenerateEmailConfirmationTokenAsync(user);
                var callbackUrl = Url.Page(
                    "/Account/ConfirmEmail",
                    pageHandler: null,
                    values: new { userId = user.Id, code = code },
                    protocol: Request.Scheme);

                Guard.Against.Null(callbackUrl, nameof(callbackUrl));
                await _emailSender.SendEmailAsync(Input!.Email!, "Confirm your email",
                    $"Please confirm your account by <a href='{HtmlEncoder.Default.Encode(callbackUrl)}'>clicking here</a>.");

                await _signInManager.SignInAsync(user, isPersistent: false);
                return LocalRedirect(returnUrl);
            }

            // Increment rate-limit counter on failure
            attempts++;
            await _distributedCache.SetAsync(
                rateLimitKey,
                System.Text.Encoding.UTF8.GetBytes(attempts.ToString()),
                new DistributedCacheEntryOptions
                {
                    AbsoluteExpirationRelativeToNow = System.TimeSpan.FromMinutes(30)
                });

            foreach (var error in result.Errors)
            {
                ModelState.AddModelError(string.Empty, error.Description);
            }
        }

        // If we got this far, something failed, redisplay form
        return Page();
    }
}
