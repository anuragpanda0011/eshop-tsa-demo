using System;

namespace Microsoft.eShopWeb.ApplicationCore.Constants;

/// <summary>
/// Authorization constants. All secrets are read from environment variables or
/// Azure Key Vault at startup — no hardcoded values exist in source code.
/// </summary>
public class AuthorizationConstants
{
    /// <summary>
    /// Cookie / auth scheme key. Loaded from environment variable AUTH_KEY.
    /// In production this value is injected via Azure Key Vault + Managed Identity.
    /// </summary>
    public static string AUTH_KEY =>
        Environment.GetEnvironmentVariable("AUTH_KEY")
        ?? throw new InvalidOperationException(
            "Required environment variable 'AUTH_KEY' is not set. " +
            "In production, bind this to the Azure Key Vault secret 'AuthKey'.");

    /// <summary>
    /// Default seed password for development environments only.
    /// Loaded from environment variable DEFAULT_PASSWORD.
    /// Must not be used in production.
    /// </summary>
    public static string DEFAULT_PASSWORD =>
        Environment.GetEnvironmentVariable("DEFAULT_PASSWORD")
        ?? throw new InvalidOperationException(
            "Required environment variable 'DEFAULT_PASSWORD' is not set. " +
            "In production, bind this to the Azure Key Vault secret 'DefaultPassword'.");

    /// <summary>
    /// JWT signing secret. Loaded from environment variable JWT_SECRET_KEY.
    /// In production this value is injected via Azure Key Vault + Managed Identity.
    /// Minimum length enforced at startup by the JWT configuration validator.
    /// </summary>
    public static string JWT_SECRET_KEY =>
        Environment.GetEnvironmentVariable("JWT_SECRET_KEY")
        ?? throw new InvalidOperationException(
            "Required environment variable 'JWT_SECRET_KEY' is not set. " +
            "In production, bind this to the Azure Key Vault secret 'JwtSecretKey'.");
}
