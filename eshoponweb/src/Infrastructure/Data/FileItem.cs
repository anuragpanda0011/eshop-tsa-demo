namespace Microsoft.eShopWeb.Infrastructure.Data;

/// <summary>
/// Represents metadata for a file stored in Azure Blob Storage.
/// The actual binary content is uploaded directly to Blob Storage
/// via the <c>AzureBlobStorageService</c>; this record carries only
/// the descriptive fields needed by other layers.
/// </summary>
public class FileItem
{
    /// <summary>Original file name as supplied by the uploader.</summary>
    public string? FileName { get; set; }

    /// <summary>
    /// Azure Blob Storage URL (HTTPS) for the stored object.
    /// Never use HTTP URLs — enforce TLS at service registration.
    /// </summary>
    public string? Url { get; set; }

    /// <summary>File size in bytes (validated against the 512 KB limit before upload).</summary>
    public long Size { get; set; }

    /// <summary>Lower-cased file extension, e.g. ".jpg".</summary>
    public string? Ext { get; set; }

    /// <summary>MIME type as validated by the blob storage service (e.g. "image/jpeg").</summary>
    public string? Type { get; set; }

    /// <summary>
    /// Optional Base64-encoded content used only during in-memory validation
    /// before the byte stream is forwarded to Azure Blob Storage.
    /// Must NOT be persisted to the database.
    /// </summary>
    public string? DataBase64 { get; set; }
}
