using System.Text.Json;
using System.Text.Json.Serialization;

namespace BlazorShared.Models;

/// <summary>
/// Standard error envelope returned by all API error responses.
/// Shape: {"error": "&lt;code&gt;", "message": "&lt;detail&gt;"}
/// </summary>
public class ErrorDetails
{
    private static readonly JsonSerializerOptions _serializerOptions = new JsonSerializerOptions
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    [JsonPropertyName("statusCode")]
    public int StatusCode { get; set; }

    /// <summary>Short machine-readable error code (e.g. "NOT_FOUND").</summary>
    [JsonPropertyName("error")]
    public string Error { get; set; } = string.Empty;

    /// <summary>Human-readable description of the error.</summary>
    [JsonPropertyName("message")]
    public string Message { get; set; } = string.Empty;

    /// <summary>
    /// Optional Azure distributed trace ID, propagated from the upstream
    /// Application Insights telemetry context.
    /// </summary>
    [JsonPropertyName("traceId")]
    public string? TraceId { get; set; }

    public override string ToString() => JsonSerializer.Serialize(this, _serializerOptions);
}
