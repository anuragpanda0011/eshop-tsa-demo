using System.Text.Json;
using System.Text.Json.Serialization;

namespace BlazorShared.Models;

/// <summary>
/// Canonical error envelope returned by all API error responses:
/// {"error": "&lt;code&gt;", "message": "&lt;detail&gt;"}
/// </summary>
public class ErrorDetails
{
    [JsonPropertyName("statusCode")]
    public int StatusCode { get; set; }

    /// <summary>Short machine-readable error code (e.g. "NOT_FOUND").</summary>
    [JsonPropertyName("error")]
    public string Error { get; set; }

    /// <summary>Human-readable detail message.</summary>
    [JsonPropertyName("message")]
    public string Message { get; set; }

    public override string ToString() =>
        JsonSerializer.Serialize(this, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });
}
