using System;
using System.Security.Cryptography;
using System.Text;

namespace Microsoft.eShopWeb.Web;

/// <summary>
/// Shared utility for hashing user-supplied strings before embedding them in
/// cache keys or other storage locations to prevent injection and data leakage.
/// </summary>
public static class HashHelper
{
    /// <summary>
    /// Returns a lowercase SHA-256 hex string of the input.
    /// </summary>
    public static string HashKey(string input)
    {
        ArgumentNullException.ThrowIfNull(input);
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(input));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }
}
