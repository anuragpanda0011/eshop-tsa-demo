using System;
using System.Collections.Generic;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Identity;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.Tokens;

namespace Microsoft.eShopWeb.Infrastructure.Identity;

/// <summary>
/// Issues signed JWT tokens for authenticated users.
///
/// Security hardening applied:
/// - The JWT signing key is read from configuration at construction time
///   (sourced from Azure Key Vault via Managed Identity — never hardcoded).
/// - The algorithm is validated against an allow-list; any unsafe or unknown
///   algorithm value causes a loud startup failure.
/// - Token lifetime is configurable; default is 7 days.
/// </summary>
public class IdentityTokenClaimService : ITokenClaimsService
{
    // Allow-listed signing algorithms. Asymmetric RS256/ES256 are preferred in
    // production; HS256 is permitted when only a symmetric key is available.
    private static readonly HashSet<string> _allowedAlgorithms = new(StringComparer.OrdinalIgnoreCase)
    {
        SecurityAlgorithms.HmacSha256,       // HS256
        SecurityAlgorithms.HmacSha384,       // HS384
        SecurityAlgorithms.HmacSha512,       // HS512
        SecurityAlgorithms.RsaSha256,        // RS256
        SecurityAlgorithms.RsaSha384,        // RS384
        SecurityAlgorithms.RsaSha512,        // RS512
        SecurityAlgorithms.EcdsaSha256,      // ES256
        SecurityAlgorithms.EcdsaSha384,      // ES384
        SecurityAlgorithms.EcdsaSha512,      // ES512
    };

    private readonly UserManager<ApplicationUser> _userManager;
    private readonly ILogger<IdentityTokenClaimService> _logger;
    private readonly string _signingAlgorithm;
    private readonly SigningCredentials _signingCredentials;
    private readonly int _tokenLifetimeDays;

    public IdentityTokenClaimService(
        UserManager<ApplicationUser> userManager,
        IConfiguration configuration,
        ILogger<IdentityTokenClaimService> logger)
    {
        _userManager = userManager;
        _logger = logger;

        // ------------------------------------------------------------------
        // Read the JWT signing key from configuration.
        // In production this value originates from Azure Key Vault
        // (secret name "JwtSigningKey") injected via Managed Identity.
        // Startup fails fast if the secret is absent or obviously weak.
        // ------------------------------------------------------------------
        var jwtKey = configuration["JwtSigningKey"]
            ?? throw new InvalidOperationException(
                "JWT signing key 'JwtSigningKey' is not configured. " +
                "Set it as an Azure Key Vault secret or an environment variable. " +
                "The key must be at least 32 bytes (256 bits) for HMAC-SHA-256.");

        if (jwtKey.Length < 32)
        {
            throw new InvalidOperationException(
                "JWT signing key 'JwtSigningKey' is too short. " +
                "Provide at least 32 characters (256 bits) for HMAC-SHA-256.");
        }

        // ------------------------------------------------------------------
        // Validate and apply the signing algorithm from configuration.
        // Fall back to HS256; refuse any algorithm not on the allow-list.
        // ------------------------------------------------------------------
        _signingAlgorithm = configuration["JwtSigningAlgorithm"]
            ?? SecurityAlgorithms.HmacSha256;

        if (!_allowedAlgorithms.Contains(_signingAlgorithm))
        {
            throw new InvalidOperationException(
                $"JWT signing algorithm '{_signingAlgorithm}' is not allowed. " +
                $"Permitted values: {string.Join(", ", _allowedAlgorithms)}.");
        }

        var keyBytes = Encoding.UTF8.GetBytes(jwtKey);
        var securityKey = new SymmetricSecurityKey(keyBytes);
        _signingCredentials = new SigningCredentials(securityKey, _signingAlgorithm);

        // Token lifetime — configurable, defaults to 7 days.
        if (!int.TryParse(configuration["JwtTokenLifetimeDays"], out _tokenLifetimeDays)
            || _tokenLifetimeDays <= 0)
        {
            _tokenLifetimeDays = 7;
        }

        _logger.LogInformation(
            "IdentityTokenClaimService initialised. Algorithm={Algorithm}, TokenLifetimeDays={Days}.",
            _signingAlgorithm, _tokenLifetimeDays);
    }

    /// <inheritdoc />
    public async Task<string> GetTokenAsync(string userName)
    {
        var user = await _userManager.FindByNameAsync(userName);
        if (user == null)
        {
            _logger.LogWarning(
                "GetTokenAsync: user '{UserName}' not found.",
                userName);
            throw new UserNotFoundException(userName);
        }

        var roles = await _userManager.GetRolesAsync(user);

        var claims = new List<Claim>
        {
            new Claim(ClaimTypes.Name, userName),
            // Include the subject (user ID) as a standard JWT claim.
            new Claim(JwtRegisteredClaimNames.Sub, user.Id),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
        };

        foreach (var role in roles)
        {
            claims.Add(new Claim(ClaimTypes.Role, role));
        }

        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims),
            Expires = DateTime.UtcNow.AddDays(_tokenLifetimeDays),
            SigningCredentials = _signingCredentials,
            // Issuer / Audience can be added from configuration if required.
        };

        var tokenHandler = new JwtSecurityTokenHandler();
        var token = tokenHandler.CreateToken(tokenDescriptor);
        var tokenString = tokenHandler.WriteToken(token);

        _logger.LogInformation(
            "Issued JWT for user '{UserName}', expires {Expires:O}.",
            userName, tokenDescriptor.Expires);

        return tokenString;
    }
}
