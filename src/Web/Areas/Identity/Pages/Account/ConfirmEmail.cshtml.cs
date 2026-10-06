using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.eShopWeb.Infrastructure.Identity;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.Web.Areas.Identity.Pages.Account;

[AllowAnonymous]
public class ConfirmEmailModel : PageModel
{
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly ILogger<ConfirmEmailModel> _logger;

    public ConfirmEmailModel(UserManager<ApplicationUser> userManager, ILogger<ConfirmEmailModel> logger)
    {
        _userManager = userManager;
        _logger = logger;
    }

    public async Task<IActionResult> OnGetAsync(string userId, string code)
    {
        if (userId == null || code == null)
        {
            _logger.LogWarning("ConfirmEmail called with null userId or code. TraceId={TraceId}",
                HttpContext.TraceIdentifier);
            return RedirectToPage("/Index");
        }

        var user = await _userManager.FindByIdAsync(userId);
        if (user == null)
        {
            _logger.LogWarning("ConfirmEmail: user not found. UserId={UserId} TraceId={TraceId}",
                userId, HttpContext.TraceIdentifier);
            return NotFound(new { error = "user_not_found", message = $"Unable to load user with ID '{userId}'." });
        }

        var result = await _userManager.ConfirmEmailAsync(user, code);
        if (!result.Succeeded)
        {
            _logger.LogError("ConfirmEmail failed for UserId={UserId} TraceId={TraceId}",
                userId, HttpContext.TraceIdentifier);
            throw new InvalidOperationException($"Error confirming email for user with ID '{userId}'.");
        }

        _logger.LogInformation("Email confirmed successfully for UserId={UserId} TraceId={TraceId}",
            userId, HttpContext.TraceIdentifier);

        return Page();
    }
}
