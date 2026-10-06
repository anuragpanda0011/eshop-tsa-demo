using System.ComponentModel.DataAnnotations;

namespace BlazorShared.Models;

public class CreateCatalogItemRequest
{
    [Range(1, int.MaxValue, ErrorMessage = "A valid CatalogTypeId is required.")]
    public int CatalogTypeId { get; set; }

    [Range(1, int.MaxValue, ErrorMessage = "A valid CatalogBrandId is required.")]
    public int CatalogBrandId { get; set; }

    [Required(ErrorMessage = "The Name field is required")]
    [StringLength(200, MinimumLength = 1, ErrorMessage = "Name must be between 1 and 200 characters.")]
    public string Name { get; set; } = string.Empty;

    [Required(ErrorMessage = "The Description field is required")]
    [StringLength(2000, ErrorMessage = "Description must not exceed 2000 characters.")]
    public string Description { get; set; } = string.Empty;

    // decimal(18,2)
    [RegularExpression(@"^\d+(\.\d{0,2})*$",
        ErrorMessage = "The field Price must be a positive number with maximum two decimals.")]
    [Range(0.01, 1000)]
    [DataType(DataType.Currency)]
    public decimal Price { get; set; } = 0;

    public string PictureUri { get; set; } = string.Empty;
    public string PictureBase64 { get; set; } = string.Empty;

    [StringLength(256, ErrorMessage = "PictureName must not exceed 256 characters.")]
    public string PictureName { get; set; } = string.Empty;
}
