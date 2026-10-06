using System;
using System.Collections.Generic;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;

namespace Microsoft.eShopWeb.FunctionalTests.Web.Api;

/// <summary>
/// Generates signed JWT tokens for use in functional tests.
///
/// SECURITY NOTES:
/// - The JWT secret is read from the environment variable FUNCTIONAL_TEST_JWT_SECRET
///   (or falls back to a long hard-coded test-only value that is never used in
///   production).  The production secret lives in Azure Key Vault.
/// - Only HmacSha256 is accepted (algorithm allowlist enforced).
/// - Tokens expire after one hour and are scoped to the test audience.
/// </summary>
public static class ApiTokenHelper
{
    // Allowlisted signing algorithm – reject anything else at build time.
    private const string AllowedAlgorithm = SecurityAlgorithms.HmacSha256Signature;

    public static string GetAdminUserToken()
    {
        return CreateToken("admin@microsoft.com", new[] { "Administrators" });
    }

    public static string GetNormalUserToken()
    {
        return CreateToken("demouser@microsoft.com", Array.Empty<string>());
    }

    private static string CreateToken(string userName, string[] roles)
    {
        // Secret resolved at runtime: env-var first, then shared test constant.
        // Never embed a production secret here.
        var rawSecret = Environment.GetEnvironmentVariable("FUNCTIONAL_TEST_JWT_SECRET")
                        ?? TestJwtSettings.TestJwtSecret;

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(rawSecret));

        var claims = new List<Claim>
        {
            new Claim(ClaimTypes.Name, userName),
            new Claim(JwtRegisteredClaimNames.Sub, userName),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
        };

        foreach (var role in roles)
        {
            claims.Add(new Claim(ClaimTypes.Role, role));
        }

        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject            = new ClaimsIdentity(claims),
            Expires            = DateTime.UtcNow.AddHours(1),
            Issuer             = "FunctionalTests",
            Audience           = "eShopOnWebAPI",
            SigningCredentials = new SigningCredentials(key, AllowedAlgorithm),
        };

        var handler = new JwtSecurityTokenHandler();
        var token   = handler.CreateToken(tokenDescriptor);
        return handler.WriteToken(token);
    }
}
