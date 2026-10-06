using System;
using System.Collections.Generic;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;

namespace Microsoft.eShopWeb.FunctionalTests.Web.Api;

/// <summary>
/// Generates short-lived JWT tokens for functional test use only.
/// The signing key is read from the JWT_SECRET_KEY environment variable
/// (minimum 32 characters). Tests will fail fast if the variable is absent
/// or the key is too short, preventing silent security mis-configurations.
/// </summary>
public static class ApiTokenHelper
{
    /// <summary>
    /// Allowed JWT signing algorithms. Only HS256 is permitted; unsafe
    /// values (e.g. "none", RS256 without key validation) are rejected.
    /// </summary>
    private static readonly IReadOnlySet<string> AllowedAlgorithms =
        new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            SecurityAlgorithms.HmacSha256Signature   // "HS256"
        };

    private static readonly string JwtSecret = GetValidatedSecret();

    private static string GetValidatedSecret()
    {
        var secret = Environment.GetEnvironmentVariable("JWT_SECRET_KEY")
                     ?? "test-secret-key-min-32-chars-long!!";

        if (secret.Length < 32)
        {
            throw new InvalidOperationException(
                "JWT_SECRET_KEY must be at least 32 characters. " +
                "Set a sufficiently long value in the test environment.");
        }

        return secret;
    }

    public static string GetAdminUserToken()
    {
        const string userName = "admin@eshoponweb.com";
        string[] roles = { "Administrators" };
        return CreateToken(userName, roles);
    }

    public static string GetNormalUserToken()
    {
        const string userName = "buyer@eshoponweb.com";
        string[] roles = Array.Empty<string>();
        return CreateToken(userName, roles);
    }

    private static string CreateToken(string userName, string[] roles)
    {
        var claims = new List<Claim> { new Claim(ClaimTypes.Name, userName) };

        foreach (var role in roles)
        {
            claims.Add(new Claim(ClaimTypes.Role, role));
        }

        var algorithm = SecurityAlgorithms.HmacSha256Signature;

        if (!AllowedAlgorithms.Contains(algorithm))
        {
            throw new InvalidOperationException(
                $"JWT algorithm '{algorithm}' is not in the allowlist.");
        }

        var key = Encoding.UTF8.GetBytes(JwtSecret);
        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims),
            Expires = DateTime.UtcNow.AddHours(1),
            SigningCredentials = new SigningCredentials(
                new SymmetricSecurityKey(key),
                algorithm)
        };

        var tokenHandler = new JwtSecurityTokenHandler();
        var token = tokenHandler.CreateToken(tokenDescriptor);
        return tokenHandler.WriteToken(token);
    }
}
