namespace Microsoft.eShopWeb.PublicApi;

/// <summary>
/// Standardised error envelope returned on all 4xx / 5xx responses.
/// Shape: { "error": "&lt;code&gt;", "message": "&lt;detail&gt;" }
/// </summary>
public class ErrorResponse
{
    public string Error   { get; }
    public string Message { get; }

    public ErrorResponse(string error, string message)
    {
        Error   = error;
        Message = message;
    }
}
