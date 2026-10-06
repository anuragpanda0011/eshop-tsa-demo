namespace Microsoft.eShopWeb.FunctionalTests.PublicApi;

/// <summary>
/// Shared test-only JWT settings.
///
/// This secret is intentionally committed and is ONLY used when running the
/// functional test suite against in-memory databases.  It must never be used
/// in any environment that is connected to real data.
///
/// In production the secret is sourced from Azure Key Vault via Managed Identity.
/// </summary>
internal static class TestJwtSettings
{
    /// <summary>
    /// A sufficiently long (≥ 32-byte) secret for HMAC-SHA256 used exclusively
    /// by the test harness.  Environment variable FUNCTIONAL_TEST_JWT_SECRET
    /// overrides this value when set.
    /// </summary>
    internal const string TestJwtSecret =
        "FunctionalTest-Only-Secret-Key-NotForProduction-32+chars";
}
