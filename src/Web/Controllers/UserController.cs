using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Azure.Messaging.ServiceBus;
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

namespace Microsoft.eShopWeb.Web.Controllers;

[Route("[controller]")]
[ApiController]
public class UserController : ControllerBase
{
    private readonly ITokenClaimsService _tokenClaimsService;
    private readonly SignInManager<ApplicationUser> _signInManager;
    private readonly ILogger<UserController> _logger;
    private readonly IDistributedCache _cache;
    private readonly ServiceBusClient? _serviceBusClient;
    private readonly string _eventsTopic;

    // TTL for the logout invalidation token stored in Redis
    private static readonly TimeSpan LogoutCacheTtl =
        TimeSpan.FromMinutes(ConfigureCookieSettings.ValidityMinutesPeriod);

    public UserController(
        ITokenClaimsService tokenClaimsService,
        SignInManager<ApplicationUser> signInManager,
        ILogger<UserController> logger,
        IDistributedCache cache,
        ServiceBusClient? serviceBusClient = null)
    {
        _tokenClaimsService = tokenClaimsService;
        _signInManager = signInManager;
        _logger = logger;
        _cache = cache;
        _serviceBusClient = serviceBusClient;
        _eventsTopic = Environment.GetEnvironmentVariable("SERVICEBUS_EVENTS_TOPIC") ?? "user-events";
    }

    [HttpGet]
    [Authorize]
    [AllowAnonymous]
    public async Task<IActionResult> GetCurrentUser() =>
        Ok(await CreateUserInfo(User));

    [Route("Logout")]
    [HttpPost]
    [Authorize]
    [AllowAnonymous]
    public async Task<IActionResult> Logout()
    {
        var userNameClaim = _signInManager.Context.User.Claims
            .FirstOrDefault(c => c.Type == ClaimTypes.Name);
        var identityKey = _signInManager.Context.Request.Cookies[ConfigureCookieSettings.IdentifierCookieName];

        await _signInManager.SignOutAsync();
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);

        if (userNameClaim != null && identityKey != null)
        {
            // Hash the composite key before using as Redis cache key
            var rawKey = $"{userNameClaim.Value}:{identityKey}";
            var hashedKey = HashCacheKey(rawKey);

            var options = new DistributedCacheEntryOptions
            {
                AbsoluteExpiration = DateTimeOffset.UtcNow.Add(LogoutCacheTtl)
            };
            await _cache.SetStringAsync(hashedKey, identityKey, options);
        }

        _logger.LogInformation(
            "User '{UserName}' logged out at {LogoutTime}.",
            userNameClaim?.Value ?? "unknown",
            DateTimeOffset.UtcNow);

        await PublishEventAsync("UserLoggedOut", new
        {
            UserName = userNameClaim?.Value,
            LoggedOutAt = DateTimeOffset.UtcNow
        });

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

    /// <summary>
    /// Returns a SHA-256 hex digest of the supplied raw key so that
    /// user-supplied strings are never used verbatim as Redis keys.
    /// </summary>
    private static string HashCacheKey(string rawKey)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(rawKey));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }

    private async Task PublishEventAsync(string eventType, object payload)
    {
        if (_serviceBusClient == null) return;
        try
        {
            var sender = _serviceBusClient.CreateSender(_eventsTopic);
            var body = JsonSerializer.Serialize(new
            {
                EventType = eventType,
                OccurredAt = DateTimeOffset.UtcNow,
                Payload = payload
            });
            var message = new ServiceBusMessage(body)
            {
                ContentType = "application/json",
                Subject = eventType
            };
            await sender.SendMessageAsync(message);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(
                "Failed to publish event '{EventType}' to Service Bus: {Error}",
                eventType,
                ex.Message);
        }
    }
}
