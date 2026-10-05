using System;
using System.IO;

namespace Microsoft.eShopWeb.PublicApi;

public static class ImageValidators
{
    // Max 5 MB to align with Azure Blob Storage upload guidance
    private const int ImageMaximumBytes = 5 * 1024 * 1024;

    private static readonly string[] AllowedExtensions =
        { ".jpg", ".jpeg", ".png", ".gif" };

    private static readonly string[] AllowedMimeTypes =
        { "image/jpeg", "image/png", "image/gif" };

    /// <summary>
    /// Validates image bytes by extension only (used when MIME type is unavailable).
    /// </summary>
    public static bool IsValidImage(this byte[] postedFile, string fileName)
    {
        return postedFile != null
            && postedFile.Length > 0
            && postedFile.Length <= ImageMaximumBytes
            && IsExtensionValid(fileName);
    }

    /// <summary>
    /// Validates image bytes by both extension and MIME type.
    /// </summary>
    public static bool IsValidImage(this byte[] postedFile, string fileName, string contentType)
    {
        return postedFile != null
            && postedFile.Length > 0
            && postedFile.Length <= ImageMaximumBytes
            && IsExtensionValid(fileName)
            && IsMimeTypeValid(contentType);
    }

    public static bool IsExtensionValid(string fileName)
    {
        var extension = Path.GetExtension(fileName);
        foreach (var allowed in AllowedExtensions)
            if (string.Equals(extension, allowed, StringComparison.OrdinalIgnoreCase))
                return true;
        return false;
    }

    public static bool IsMimeTypeValid(string contentType)
    {
        foreach (var allowed in AllowedMimeTypes)
            if (string.Equals(contentType, allowed, StringComparison.OrdinalIgnoreCase))
                return true;
        return false;
    }

    public static int MaxBytes => ImageMaximumBytes;
}
