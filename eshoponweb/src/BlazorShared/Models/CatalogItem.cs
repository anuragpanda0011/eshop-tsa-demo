using System;
using System.ComponentModel.DataAnnotations;
using System.IO;
using System.Threading.Tasks;
using BlazorInputFile;

namespace BlazorShared.Models;

public class CatalogItem
{
    /// <summary>
    /// Allowed image MIME extensions — kept in sync with server-side MIME validation.
    /// </summary>
    private static readonly string[] AllowedExtensions =
    {
        ".jpg", ".jpeg", ".png", ".gif"
    };

    /// <summary>Maximum image payload: 512 KB.</summary>
    private const int ImageMaximumBytes = 512_000;

    public int Id { get; set; }

    public int CatalogTypeId { get; set; }
    public string CatalogType { get; set; } = "NotSet";

    public int CatalogBrandId { get; set; }
    public string CatalogBrand { get; set; } = "NotSet";

    [Required(ErrorMessage = "The Name field is required")]
    public string Name { get; set; }

    [Required(ErrorMessage = "The Description field is required")]
    public string Description { get; set; }

    [RegularExpression(
        @"^\d+(\.\d{0,2})*$",
        ErrorMessage = "The field Price must be a positive number with maximum two decimals.")]
    [Range(0.01, 1000)]
    [DataType(DataType.Currency)]
    public decimal Price { get; set; }

    public string PictureUri { get; set; }
    public string PictureBase64 { get; set; }
    public string PictureName { get; set; }

    /// <summary>
    /// Validates an image supplied as a Base64 string.
    /// Returns null on success; otherwise an error message.
    /// </summary>
    public static string IsValidImage(string pictureName, string pictureBase64)
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
            return "Image data is not valid Base64.";
        }

        if (fileData.Length <= 0)
            return "File length is 0!";

        if (fileData.Length > ImageMaximumBytes)
            return "Maximum length is 512 KB.";

        if (!IsExtensionValid(pictureName))
            return "File is not a supported image type (.jpg, .jpeg, .png, .gif).";

        return null;
    }

    public static async Task<string> DataToBase64(IFileListEntry fileItem)
    {
        using var reader = new StreamReader(fileItem.Data);
        using var memStream = new MemoryStream();
        await reader.BaseStream.CopyToAsync(memStream);
        return Convert.ToBase64String(memStream.ToArray());
    }

    private static bool IsExtensionValid(string fileName)
    {
        if (string.IsNullOrWhiteSpace(fileName))
            return false;

        var extension = Path.GetExtension(fileName);
        foreach (var allowed in AllowedExtensions)
        {
            if (string.Equals(extension, allowed, StringComparison.OrdinalIgnoreCase))
                return true;
        }

        return false;
    }
}
