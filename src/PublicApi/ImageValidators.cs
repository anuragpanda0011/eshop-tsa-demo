using System;
using System.IO;

namespace Microsoft.eShopWeb.PublicApi;

public static class ImageValidators
{
    // 512 KB maximum; override via env var IMAGE_MAX_BYTES
    private static readonly int ImageMaximumBytes = int.TryParse(
        Environment.GetEnvironmentVariable("IMAGE_MAX_BYTES"), out var parsed) ? parsed : 512000;

    private static readonly string[] AllowedMimeTypes =
    {
        "image/jpeg",
        "image/png",
        "image/gif"
    };

    private static readonly string[] AllowedExtensions =
    {
        ".jpg",
        ".jpeg",
        ".png",
        ".gif"
    };

    public static bool IsValidImage(this byte[] postedFile, string fileName)
    {
        return postedFile != null
               && postedFile.Length > 0
               && postedFile.Length <= ImageMaximumBytes
               && IsExtensionValid(fileName)
               && HasValidImageHeader(postedFile);
    }

    /// <summary>
    /// Validates that the MIME type is in the allowed list.
    /// </summary>
    public static bool IsAllowedMimeType(string mimeType)
    {
        return Array.Exists(AllowedMimeTypes,
            m => string.Equals(m, mimeType, StringComparison.OrdinalIgnoreCase));
    }

    private static bool IsExtensionValid(string fileName)
    {
        var extension = Path.GetExtension(fileName);
        return Array.Exists(AllowedExtensions,
            e => string.Equals(e, extension, StringComparison.OrdinalIgnoreCase));
    }

    /// <summary>
    /// Checks magic bytes to guard against extension-spoofed uploads.
    /// </summary>
    private static bool HasValidImageHeader(byte[] bytes)
    {
        if (bytes.Length < 4) return false;

        // JPEG: FF D8 FF
        if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
        // PNG: 89 50 4E 47
        if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true;
        // GIF: 47 49 46 38
        if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) return true;

        return false;
    }
}
