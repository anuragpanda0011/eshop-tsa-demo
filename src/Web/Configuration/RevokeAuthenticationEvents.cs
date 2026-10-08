using System;
using System.Linq;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.Web.Configuration;

/// <summary>
/// Checks whether the current session token has been revoked (e.g. after logout).
/// Uses Azure Cache for Redis (IDistributedCache) so this works correctly in
/// multi-instance / Container Apps deployments.
/// </summary>
public class RevokeAuthenticationEvents : CookieAuthenticationEvents
{
    private readonly IDistributedCache _cache;
    private readonly ILogger<RevokeAuthenticationEvents> _logger;

    public RevokeAuthenticationEvents(
        IDistributedCache cache,
        ILogger<RevokeAuthenticationEvents> logger)
    {
        _cache = cache;
        _logger = logger;
    }

    public override async Task ValidatePrincipal(CookieValidatePrincipalContext context)
    {
        var userId = context.Principal?.Claims.FirstOrDefault(c => c.Type == ClaimTypes.Name);
        var identityKey = context.Request.Cookies[ConfigureCookieSettings.IdentifierCookieName];

        if (userId == null || identityKey == null)
            return;

        // Hash the key before using it as a cache lookup (user-supplied string)
        var rawKey = $"{userId.Value}:{identityKey}";
        var hashedKey = Convert.ToHexString(
            System.Security.Cryptography.SHA256.HashData(
                Encoding.UTF8.GetBytes(rawKey))).ToLowerInvariant();

        var revokedEntry = await _cache.GetStringAsync(hashedKey);
        if (revokedEntry != null)
        {
            _logger.LogInformation(
                "Access revoked for UserId={UserId}. Rejecting principal.",
                userId.Value);
            context.RejectPrincipal();
            await context.HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        }
    }
}
