namespace BlazorShared;

public class BaseUrlConfiguration
{
    public const string CONFIG_NAME = "baseUrls";

    /// <summary>
    /// Base URL for the Public API (must use HTTPS in non-development environments).
    /// Sourced from configuration / Azure Key Vault — never hardcoded.
    /// </summary>
    public string ApiBase { get; set; }

    /// <summary>
    /// Base URL for the Web frontend.
    /// Sourced from configuration / Azure Key Vault — never hardcoded.
    /// </summary>
    public string WebBase { get; set; }
}
