using System;
using System.Text.Json;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.Infrastructure.Logging;

public class LoggerAdapter<T> : IAppLogger<T>
{
    private readonly ILogger<T> _logger;

    public LoggerAdapter(ILoggerFactory loggerFactory)
    {
        _logger = loggerFactory.CreateLogger<T>();
    }

    public void LogWarning(string message, params object[] args)
    {
        _logger.LogWarning(BuildStructuredMessage(message, args));
    }

    public void LogInformation(string message, params object[] args)
    {
        _logger.LogInformation(BuildStructuredMessage(message, args));
    }

    /// <summary>
    /// Wraps the message in a structured JSON envelope so that every log line
    /// emitted to stdout is machine-parseable by Azure Monitor / Log Analytics.
    /// The Azure trace ID is picked up from the ambient Activity if present.
    /// </summary>
    private static string BuildStructuredMessage(string message, object[] args)
    {
        var traceId = System.Diagnostics.Activity.Current?.TraceId.ToString() ?? string.Empty;
        var spanId  = System.Diagnostics.Activity.Current?.SpanId.ToString()  ?? string.Empty;

        // Substitute positional args into the message template (best-effort).
        string formattedMessage = message;
        try
        {
            if (args is { Length: > 0 })
                formattedMessage = string.Format(message, args);
        }
        catch
        {
            // If format fails, fall back to the raw template.
        }

        var envelope = new
        {
            timestamp  = DateTimeOffset.UtcNow.ToString("o"),
            traceId,
            spanId,
            message    = formattedMessage,
            logger     = typeof(T).FullName
        };

        return JsonSerializer.Serialize(envelope);
    }
}
