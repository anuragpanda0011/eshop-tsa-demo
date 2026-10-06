namespace Microsoft.eShopWeb.Infrastructure.Data;

/// <summary>
/// Represents file metadata returned from Azure Blob Storage uploads.
/// Actual blob storage operations are performed via AzureBlobStorageService.
/// </summary>
public class FileItem
{
    /// <summary>Original file name (sanitized before use as blob name).</summary>
    public string? FileName { get; set; }

    /// <summary>Publicly accessible or SAS-signed URL of the uploaded blob.</summary>
    public string? Url { get; set; }

    /// <summary>File size in bytes.</summary>
    public long Size { get; set; }

    /// <summary>File extension (e.g. ".png").</summary>
    public string? Ext { get; set; }

    /// <summary>MIME type validated against the allowed-types allowlist.</summary>
    public string? Type { get; set; }

    /// <summary>
    /// Base-64 encoded file contents.
    /// Only populated for small payloads; large files are streamed directly
    /// to Azure Blob Storage and this property is left null.
    /// </summary>
    public string? DataBase64 { get; set; }
}
