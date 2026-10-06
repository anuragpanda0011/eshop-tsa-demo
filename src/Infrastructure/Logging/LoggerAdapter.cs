using System;
using System.Diagnostics;
using System.Text.Json;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.Infrastructure.Logging;

/// <summary>
/// Adapter that emits structured JSON log lines to stdout and attaches the
/// current Azure / W3C trace-id to every log entry so Application Insights
/// can correlate distributed traces automatically.
/// </summary>
public class LoggerAdapter<T> : IAppLogger<T>
{
    private readonly ILogger<T> _logger;

    public LoggerAdapter(ILoggerFactory loggerFactory)
    {
        _logger = loggerFactory.CreateLogger<T>();
    }

    public void LogWarning(string message, params object[] args)
    {
        using (_logger.BeginScope(BuildScope()))
        {
            _logger.LogWarning(message, args);
        }
    }

    public void LogInformation(string message, params object[] args)
    {
        using (_logger.BeginScope(BuildScope()))
        {
            _logger.LogInformation(message, args);
        }
    }

    // -----------------------------------------------------------------------
    // Private helpers
    // -----------------------------------------------------------------------

    /// <summary>
    /// Builds a log-scope dictionary that the JSON console formatter will
    /// serialize as extra fields on every emitted log line, giving us the
    /// Azure correlation / trace IDs for free.
    /// </summary>
    private static System.Collections.Generic.Dictionary<string, object> BuildScope()
    {
        var scope = new System.Collections.Generic.Dictionary<string, object>
        {
            ["component"] = typeof(T).FullName ?? typeof(T).Name,
            ["timestamp"] = DateTimeOffset.UtcNow.ToString("O")
        };

        // W3C traceparent / Azure Application Insights operation id
        var activity = Activity.Current;
        if (activity is not null)
        {
            scope["traceId"] = activity.TraceId.ToString();
            scope["spanId"]  = activity.SpanId.ToString();

            // Azure-specific: the operation id header propagated by App Insights SDK
            var operationId = activity.GetBaggageItem("ai_operation_id");
            if (!string.IsNullOrEmpty(operationId))
            {
                scope["ai_operation_id"] = operationId;
            }
        }

        return scope;
    }
}
