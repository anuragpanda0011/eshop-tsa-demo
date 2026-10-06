using System;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Ardalis.ApiEndpoints;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.eShopWeb.Infrastructure.Identity;
using Microsoft.Extensions.Logging;
using Swashbuckle.AspNetCore.Annotations;

namespace Microsoft.eShopWeb.PublicApi.AuthEndpoints;

/// <summary>
/// Authenticates a user and returns a JWT bearer token.
/// Rate-limited to prevent brute-force attacks.
/// Route: POST /api/v1/authenticate
/// </summary>
[EnableRateLimiting("auth")]
public class AuthenticateEndpoint : EndpointBaseAsync
    .WithRequest<AuthenticateRequest>
    .WithActionResult<AuthenticateResponse>
{
    private readonly SignInManager<ApplicationUser> _signInManager;
    private readonly ITokenClaimsService _tokenClaimsService;
    private readonly ILogger<AuthenticateEndpoint> _logger;

    public AuthenticateEndpoint(
        SignInManager<ApplicationUser> signInManager,
        ITokenClaimsService tokenClaimsService,
        ILogger<AuthenticateEndpoint> logger)
    {
        _signInManager       = signInManager;
        _tokenClaimsService  = tokenClaimsService;
        _logger              = logger;
    }

    [HttpPost("/api/v1/authenticate")]
    [SwaggerOperation(
        Summary     = "Authenticates a user",
        Description = "Validates credentials and returns a JWT bearer token. Rate-limited.",
        OperationId = "auth.authenticate",
        Tags        = new[] { "AuthEndpoints" })
    ]
    [ProducesResponseType(typeof(AuthenticateResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status429TooManyRequests)]
    public override async Task<ActionResult<AuthenticateResponse>> HandleAsync(
        AuthenticateRequest request,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(request.Username) || string.IsNullOrWhiteSpace(request.Password))
        {
            return BadRequest(new ErrorResponse("validation_error", "Username and password are required."));
        }

        var response = new AuthenticateResponse(request.CorrelationId());

        // lockoutOnFailure: true — increments lockout counter on each bad attempt.
        var result = await _signInManager.PasswordSignInAsync(
            request.Username,
            request.Password,
            isPersistent: false,
            lockoutOnFailure: true);

        response.Result              = result.Succeeded;
        response.IsLockedOut         = result.IsLockedOut;
        response.IsNotAllowed        = result.IsNotAllowed;
        response.RequiresTwoFactor   = result.RequiresTwoFactor;
        response.Username            = request.Username;

        if (result.Succeeded)
        {
            response.Token = await _tokenClaimsService.GetTokenAsync(request.Username);
        }

        _logger.LogInformation(JsonSerializer.Serialize(new
        {
            timestamp   = DateTimeOffset.UtcNow.ToString("o"),
            traceId     = HttpContext.TraceIdentifier,
            @event      = "AuthAttempt",
            username    = request.Username,
            succeeded   = result.Succeeded,
            isLockedOut = result.IsLockedOut
        }));

        return response;
    }
}
