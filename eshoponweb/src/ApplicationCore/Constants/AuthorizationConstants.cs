using System;

namespace Microsoft.eShopWeb.ApplicationCore.Constants;

/// <summary>
/// Authorization constants — all secret values are read from environment variables
/// at startup. No literal secrets are stored here. In production these env-vars are
/// populated from Azure Key Vault via the App Service Key Vault reference feature or
/// the AZD/Bicep wiring.
/// </summary>
public static class AuthorizationConstants
{
    /// <summary>
    /// The symmetric key used to sign/validate JWT tokens.
    /// Sourced from the JWT_SECRET_KEY environment variable (or Azure Key Vault secret
    /// surfaced as that env-var). Throws at startup if the variable is absent so that
    /// a misconfigured deployment fails fast rather than running with a weak key.
    /// </summary>
    public static string JWT_SECRET_KEY
    {
        get
        {
            var key = Environment.GetEnvironmentVariable("JWT_SECRET_KEY");
            if (string.IsNullOrWhiteSpace(key))
                throw new InvalidOperationException(
                    "Required environment variable 'JWT_SECRET_KEY' is not set. " +
                    "Configure it via Azure Key Vault / App Service application settings.");
            if (key.Length < 32)
                throw new InvalidOperationException(
                    "JWT_SECRET_KEY must be at least 32 characters long.");
            return key;
        }
    }

    /// <summary>
    /// Allowlisted JWT signing algorithms. The token-validation code must reject
    /// any algorithm not in this set (prevents the 'alg:none' and RS/HS confusion
    /// attacks).
    /// </summary>
    public static readonly IReadOnlyList<string> AllowedJwtAlgorithms =
        new[] { "HS256", "HS384", "HS512" };

    /// <summary>
    /// Default seed password sourced from an environment variable.
    /// Only used during database seeding in non-production environments.
    /// </summary>
    public static string DEFAULT_PASSWORD
    {
        get
        {
            var pw = Environment.GetEnvironmentVariable("SEED_DEFAULT_PASSWORD");
            if (string.IsNullOrWhiteSpace(pw))
                throw new InvalidOperationException(
                    "Required environment variable 'SEED_DEFAULT_PASSWORD' is not set.");
            return pw;
        }
    }
}
