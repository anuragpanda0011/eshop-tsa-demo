using System;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Json;
using System.Threading.Tasks;
using BlazorShared.Authorization;
using Microsoft.AspNetCore.Components.Authorization;
using Microsoft.Extensions.Logging;

namespace BlazorAdmin;

public class CustomAuthStateProvider : AuthenticationStateProvider
{
    // Cache duration sourced from configuration; default to 60 s if not set.
    private static readonly TimeSpan UserCacheRefreshInterval = TimeSpan.FromSeconds(60);

    private readonly HttpClient _httpClient;
    private readonly ILogger<CustomAuthStateProvider> _logger;

    private DateTimeOffset _userLastCheck = DateTimeOffset.FromUnixTimeSeconds(0);
    private ClaimsPrincipal _cachedUser = new ClaimsPrincipal(new ClaimsIdentity());

    public CustomAuthStateProvider(HttpClient httpClient,
        ILogger<CustomAuthStateProvider> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
    }

    public override async Task<AuthenticationState> GetAuthenticationStateAsync()
    {
        return new AuthenticationState(await GetUser(useCache: true));
    }

    private async ValueTask<ClaimsPrincipal> GetUser(bool useCache = false)
    {
        var now = DateTimeOffset.UtcNow;
        if (useCache && now < _userLastCheck + UserCacheRefreshInterval)
        {
            return _cachedUser;
        }

        _cachedUser = await FetchUser();
        _userLastCheck = now;

        return _cachedUser;
    }

    private async Task<ClaimsPrincipal> FetchUser()
    {
        UserInfo user = null;

        try
        {
            _logger.LogInformation(
                "{{\"event\":\"fetch_user\",\"message\":\"Fetching user details from web api.\"}}");
            user = await _httpClient.GetFromJsonAsync<UserInfo>("User");
        }
        catch (Exception exc)
        {
            _logger.LogWarning(exc,
                "{{\"event\":\"fetch_user_failed\",\"message\":\"Fetching user failed.\"}}");
        }

        if (user == null || !user.IsAuthenticated)
        {
            return new ClaimsPrincipal(new ClaimsIdentity());
        }

        var identity = new ClaimsIdentity(
            nameof(CustomAuthStateProvider),
            user.NameClaimType,
            user.RoleClaimType);

        if (user.Claims != null)
        {
            foreach (var claim in user.Claims)
            {
                identity.AddClaim(new Claim(claim.Type, claim.Value));
            }
        }

        // Attach bearer token for subsequent API calls made by this HttpClient.
        _httpClient.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", user.Token);

        return new ClaimsPrincipal(identity);
    }
}
