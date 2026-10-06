using Microsoft.IdentityModel.Tokens;
using System;
using System.Collections.Generic;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace PublicApiIntegrationTests
{
    public class ApiTokenHelper
    {
        // JWT secret is read from the environment; never hardcoded.
        // In CI set ESHOPONWEB_JWT_SECRET to a sufficiently long random string.
        private static readonly string JwtSecret =
            Environment.GetEnvironmentVariable("ESHOPONWEB_JWT_SECRET")
            ?? throw new InvalidOperationException(
                "Environment variable ESHOPONWEB_JWT_SECRET is not set. " +
                "Set it to a 32-character-minimum secret before running integration tests.");

        public static string GetAdminUserToken()
        {
            string userName = "admin@microsoft.com";
            string[] roles = { "Administrators" };
            return CreateToken(userName, roles);
        }

        public static string GetNormalUserToken()
        {
            string userName = "demouser@microsoft.com";
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

            // Validate key length — HS256 requires at least 128 bits (16 bytes);
            // we enforce 32 bytes (256 bits) to match production policy.
            var keyBytes = Encoding.UTF8.GetBytes(JwtSecret);
            if (keyBytes.Length < 32)
            {
                throw new InvalidOperationException(
                    "ESHOPONWEB_JWT_SECRET must be at least 32 UTF-8 bytes for HS256.");
            }

            var tokenDescriptor = new SecurityTokenDescriptor
            {
                Subject = new ClaimsIdentity(claims),
                Expires = DateTime.UtcNow.AddHours(1),
                SigningCredentials = new SigningCredentials(
                    new SymmetricSecurityKey(keyBytes),
                    // Allowlisted algorithm — only HmacSha256 is accepted.
                    SecurityAlgorithms.HmacSha256Signature)
            };

            var tokenHandler = new JwtSecurityTokenHandler();
            var token = tokenHandler.CreateToken(tokenDescriptor);
            return tokenHandler.WriteToken(token);
        }
    }
}
