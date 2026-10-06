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
/// Cookie authentication events that check a distributed (Redis-backed) revocation cache.
/// Replaces the former IMemoryCache implementation to support multi-host deployments.
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
        {
            return;
        }

        var cacheKey = HashHelper.HashKey($"{userId.Value}:{identityKey}");
        var revokedValue = await _cache.GetAsync(cacheKey);

        if (revokedValue != null)
        {
            _logger.LogInformation(
                "Access has been revoked for UserId={UserId} TraceId={TraceId}.",
                userId.Value,
                context.HttpContext.TraceIdentifier);

            context.RejectPrincipal();
            await context.HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        }
    }
}
