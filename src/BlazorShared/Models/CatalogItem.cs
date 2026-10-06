using System;
using System.ComponentModel.DataAnnotations;
using System.IO;
using System.Threading.Tasks;
using BlazorInputFile;

namespace BlazorShared.Models;

public class CatalogItem
{
    /// <summary>
    /// Maximum allowed image size in bytes (512 KB).
    /// </summary>
    private const int ImageMaximumBytes = 512_000;

    private static readonly string[] AllowedExtensions =
        { ".jpg", ".jpeg", ".png", ".gif" };

    private static readonly string[] AllowedMimeSniffs =
        {
            // JPEG: FF D8 FF
            "\xFF\xD8\xFF",
            // PNG: 89 50 4E 47
            "\x89\x50\x4E\x47",
            // GIF87a / GIF89a
            "GIF87a",
            "GIF89a"
        };

    public int Id { get; set; }

    public int CatalogTypeId { get; set; }
    public string CatalogType { get; set; } = "NotSet";

    public int CatalogBrandId { get; set; }
    public string CatalogBrand { get; set; } = "NotSet";

    [Required(ErrorMessage = "The Name field is required")]
    public string Name { get; set; } = string.Empty;

    [Required(ErrorMessage = "The Description field is required")]
    public string Description { get; set; } = string.Empty;

    // decimal(18,2)
    [RegularExpression(@"^\d+(\.\d{0,2})*$",
        ErrorMessage = "The field Price must be a positive number with maximum two decimals.")]
    [Range(0.01, 1000)]
    [DataType(DataType.Currency)]
    public decimal Price { get; set; }

    public string PictureUri { get; set; } = string.Empty;
    public string PictureBase64 { get; set; } = string.Empty;
    public string PictureName { get; set; } = string.Empty;

    /// <summary>
    /// Validates a base-64-encoded image. Returns null on success or an error message.
    /// </summary>
    public static string? IsValidImage(string? pictureName, string? pictureBase64)
    {
        if (string.IsNullOrEmpty(pictureBase64))
            return "File not found!";

        byte[] fileData;
        try
        {
            fileData = Convert.FromBase64String(pictureBase64);
        }
        catch (FormatException)
        {
            return "Invalid base-64 image data.";
        }

        if (fileData.Length <= 0)
            return "File length is 0!";

        if (fileData.Length > ImageMaximumBytes)
            return "Maximum length is 512 KB.";

        if (!IsExtensionValid(pictureName))
            return "File extension is not a supported image type (.jpg, .jpeg, .png, .gif).";

        if (!HasValidImageHeader(fileData))
            return "File content does not match a supported image format.";

        return null;
    }

    /// <summary>
    /// Reads the IFileListEntry stream and returns its base-64 representation.
    /// </summary>
    public static async Task<string> DataToBase64(IFileListEntry fileItem)
    {
        using var memStream = new MemoryStream();
        await fileItem.Data.CopyToAsync(memStream);
        return Convert.ToBase64String(memStream.ToArray());
    }

    // ── private helpers ────────────────────────────────────────────────────────

    private static bool IsExtensionValid(string? fileName)
    {
        if (string.IsNullOrEmpty(fileName)) return false;

        var extension = Path.GetExtension(fileName);
        foreach (var allowed in AllowedExtensions)
        {
            if (string.Equals(extension, allowed, StringComparison.OrdinalIgnoreCase))
                return true;
        }
        return false;
    }

    /// <summary>
    /// Checks the magic-byte signature of the raw image data so that a user
    /// cannot rename an executable to ".jpg" and bypass extension validation.
    /// </summary>
    private static bool HasValidImageHeader(byte[] data)
    {
        if (data.Length < 6) return false;

        // JPEG: FF D8 FF
        if (data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF)
            return true;

        // PNG: 89 50 4E 47 0D 0A 1A 0A
        if (data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47)
            return true;

        // GIF87a / GIF89a
        if (data[0] == 'G' && data[1] == 'I' && data[2] == 'F' &&
            data[3] == '8' && (data[4] == '7' || data[4] == '9') && data[5] == 'a')
            return true;

        return false;
    }
}
