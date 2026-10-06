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

public class IdentityTokenClaimService : ITokenClaimsService
{
    // Allowlist of accepted signing algorithms — refuse anything not on this list.
    private static readonly HashSet<string> _allowedAlgorithms = new(StringComparer.Ordinal)
    {
        SecurityAlgorithms.HmacSha256Signature,
        SecurityAlgorithms.HmacSha384Signature,
        SecurityAlgorithms.HmacSha512Signature,
    };

    private readonly UserManager<ApplicationUser> _userManager;
    private readonly IConfiguration _configuration;
    private readonly ILogger<IdentityTokenClaimService> _logger;

    public IdentityTokenClaimService(
        UserManager<ApplicationUser> userManager,
        IConfiguration configuration,
        ILogger<IdentityTokenClaimService> logger)
    {
        _userManager = userManager;
        _configuration = configuration;
        _logger = logger;

        // Validate the configured algorithm at startup so the service fails fast
        // if an unsafe or missing value is present.
        var configuredAlgorithm = _configuration["JwtSettings:Algorithm"]
                                  ?? SecurityAlgorithms.HmacSha256Signature;

        if (!_allowedAlgorithms.Contains(configuredAlgorithm))
        {
            throw new InvalidOperationException(
                $"JWT signing algorithm '{configuredAlgorithm}' is not on the allowlist. " +
                $"Permitted values: {string.Join(", ", _allowedAlgorithms)}");
        }
    }

    public async Task<string> GetTokenAsync(string userName)
    {
        // The JWT secret key MUST be supplied via environment variable or
        // Azure Key Vault — never hardcoded.
        // Expected config key: JwtSettings:SecretKey
        // Expected env-var:    JwtSettings__SecretKey
        var secretKey = _configuration["JwtSettings:SecretKey"];
        if (string.IsNullOrWhiteSpace(secretKey))
        {
            throw new InvalidOperationException(
                "JWT secret key is not configured. " +
                "Set the 'JwtSettings__SecretKey' environment variable or Key Vault secret.");
        }

        if (secretKey.Length < 32)
        {
            throw new InvalidOperationException(
                "JWT secret key is too short. It must be at least 32 characters.");
        }

        var algorithm = _configuration["JwtSettings:Algorithm"]
                        ?? SecurityAlgorithms.HmacSha256Signature;

        if (!_allowedAlgorithms.Contains(algorithm))
        {
            throw new InvalidOperationException(
                $"JWT signing algorithm '{algorithm}' is not on the allowlist.");
        }

        var tokenHandler = new JwtSecurityTokenHandler();
        var key = Encoding.UTF8.GetBytes(secretKey);

        var user = await _userManager.FindByNameAsync(userName);
        if (user == null)
        {
            _logger.LogWarning(
                "Token requested for unknown user '{UserName}'.",
                userName);
            throw new UserNotFoundException(userName);
        }

        var roles = await _userManager.GetRolesAsync(user);
        var claims = new List<Claim> { new Claim(ClaimTypes.Name, userName) };

        foreach (var role in roles)
        {
            claims.Add(new Claim(ClaimTypes.Role, role));
        }

        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims.ToArray()),
            Expires = DateTime.UtcNow.AddDays(7),
            SigningCredentials = new SigningCredentials(
                new SymmetricSecurityKey(key),
                algorithm)
        };

        var token = tokenHandler.CreateToken(tokenDescriptor);
        var tokenString = tokenHandler.WriteToken(token);

        _logger.LogInformation(
            "JWT issued for user '{UserName}'. Expires={Expires}",
            userName,
            tokenDescriptor.Expires);

        return tokenString;
    }
}
