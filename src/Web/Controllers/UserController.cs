using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;
using BlazorShared.Authorization;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.eShopWeb.Infrastructure.Identity;
using Microsoft.eShopWeb.Web.Configuration;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.Web.Controllers;

[Route("api/v1/[controller]")]
[ApiController]
public class UserController : ControllerBase
{
    private readonly ITokenClaimsService _tokenClaimsService;
    private readonly SignInManager<ApplicationUser> _signInManager;
    private readonly ILogger<UserController> _logger;
    private readonly IDistributedCache _cache;

    public UserController(
        ITokenClaimsService tokenClaimsService,
        SignInManager<ApplicationUser> signInManager,
        ILogger<UserController> logger,
        IDistributedCache cache)
    {
        _tokenClaimsService = tokenClaimsService;
        _signInManager = signInManager;
        _logger = logger;
        _cache = cache;
    }

    [HttpGet]
    [AllowAnonymous]
    public async Task<IActionResult> GetCurrentUser() =>
        Ok(await CreateUserInfo(User));

    [HttpPost("logout")]
    [Authorize]
    public async Task<IActionResult> Logout()
    {
        var userId = _signInManager.Context.User.Claims.FirstOrDefault(c => c.Type == ClaimTypes.Name);
        var identityKey = _signInManager.Context.Request.Cookies[ConfigureCookieSettings.IdentifierCookieName];

        await _signInManager.SignOutAsync();
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);

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

        _logger.LogInformation("User logged out via API. TraceId={TraceId}", HttpContext.TraceIdentifier);
        return Ok();
    }

    private async Task<UserInfo> CreateUserInfo(ClaimsPrincipal claimsPrincipal)
    {
        if (claimsPrincipal.Identity == null
            || claimsPrincipal.Identity.Name == null
            || !claimsPrincipal.Identity.IsAuthenticated)
        {
            return UserInfo.Anonymous;
        }

        var userInfo = new UserInfo
        {
            IsAuthenticated = true
        };

        if (claimsPrincipal.Identity is ClaimsIdentity claimsIdentity)
        {
            userInfo.NameClaimType = claimsIdentity.NameClaimType;
            userInfo.RoleClaimType = claimsIdentity.RoleClaimType;
        }
        else
        {
            userInfo.NameClaimType = "name";
            userInfo.RoleClaimType = "role";
        }

        if (claimsPrincipal.Claims.Any())
        {
            var claims = new List<ClaimValue>();
            var nameClaims = claimsPrincipal.FindAll(userInfo.NameClaimType);
            foreach (var claim in nameClaims)
            {
                claims.Add(new ClaimValue(userInfo.NameClaimType, claim.Value));
            }

            foreach (var claim in claimsPrincipal.Claims.Except(nameClaims))
            {
                claims.Add(new ClaimValue(claim.Type, claim.Value));
            }

            userInfo.Claims = claims;
        }

        var token = await _tokenClaimsService.GetTokenAsync(claimsPrincipal.Identity.Name);
        userInfo.Token = token;

        return userInfo;
    }
}
