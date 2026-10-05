namespace Microsoft.eShopOnWeb.ApplicationCore.Constants;

/// <summary>
/// Authorization policy / role name constants.
/// ALL SECRETS (JWT keys, default passwords) have been removed from this file.
/// They are loaded exclusively from Azure Key Vault at runtime via Managed
/// Identity — see src/PublicApi/Configuration/ApiSettings.cs and
/// src/Infrastructure/Services/TokenClaimsService.cs.
/// </summary>
public static class AuthorizationConstants
{
    public const string ADMINISTRATORS_ROLE = "Administrators";

    // Policy names used in [Authorize(Policy = ...)] attributes
    public const string CATALOG_READ_POLICY  = "CatalogRead";
    public const string CATALOG_WRITE_POLICY = "CatalogWrite";
    public const string ORDER_READ_POLICY    = "OrderRead";

    // REMOVED: string DEFAULT_PASSWORD — was "Pass@word1" (hardcoded secret)
    // REMOVED: string JWT_SECRET_KEY   — was a literal key (hardcoded secret)
    // Both values are now required Key Vault secrets:
    //   Key Vault secret name: "DefaultAdminPassword"
    //   Key Vault secret name: "JwtSecretKey"
}
