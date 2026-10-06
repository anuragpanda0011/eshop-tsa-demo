namespace BlazorShared;

public class BaseUrlConfiguration
{
    public const string CONFIG_NAME = "baseUrls";

    /// <summary>
    /// Base URL for the Public API (e.g. https://api.contoso.com/api/v1/).
    /// Populated from configuration / Key Vault — never hardcoded.
    /// </summary>
    public string ApiBase { get; set; } = string.Empty;

    /// <summary>
    /// Base URL for the Web frontend (e.g. https://www.contoso.com/).
    /// Populated from configuration / Key Vault — never hardcoded.
    /// </summary>
    public string WebBase { get; set; } = string.Empty;
}
