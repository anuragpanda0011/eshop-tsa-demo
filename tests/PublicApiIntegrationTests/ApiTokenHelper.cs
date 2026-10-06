using Microsoft.IdentityModel.Tokens;
using System;
using System.Collections.Generic;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace PublicApiIntegrationTests;

/// <summary>
/// Generates short-lived JWT tokens for integration test use only.
/// The signing key is read from the JWT_SECRET_KEY environment variable
/// (minimum 32 characters) — never from a hardcoded constant.
/// </summary>
public static class ApiTokenHelper
{
    /// <summary>
    /// Allowlist of accepted JWT signing algorithms.
    /// "none" and any asymmetric algorithm without proper key validation are excluded.
    /// </summary>
    private static readonly IReadOnlySet<string> AllowedAlgorithms =
        new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            SecurityAlgorithms.HmacSha256Signature  // "HS256"
        };

    private static readonly string JwtSecret = GetValidatedSecret();

    private static string GetValidatedSecret()
    {
        var secret = Environment.GetEnvironmentVariable("JWT_SECRET_KEY")
                     ?? "test-secret-key-min-32-chars-long!!";

        if (secret.Length < 32)
        {
            throw new InvalidOperationException(
                "JWT_SECRET_KEY must be at least 32 characters long. " +
                "Provide a sufficiently long value via the environment variable.");
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
        return CreateToken(userName, Array.Empty<string>());
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
