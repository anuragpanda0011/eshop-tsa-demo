using System;
using System.Net;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.eShopWeb.ApplicationCore.Exceptions;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.PublicApi.Middleware;

public class ExceptionMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionMiddleware> _logger;

    public ExceptionMiddleware(RequestDelegate next, ILogger<ExceptionMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext httpContext)
    {
        try
        {
            await _next(httpContext);
        }
        catch (Exception ex)
        {
            await HandleExceptionAsync(httpContext, ex);
        }
    }

    private async Task HandleExceptionAsync(HttpContext context, Exception exception)
    {
        var traceId = context.TraceIdentifier;

        context.Response.ContentType = "application/json";

        object errorBody;
        if (exception is DuplicateException duplicationException)
        {
            context.Response.StatusCode = (int)HttpStatusCode.Conflict;
            errorBody = new { error = "duplicate", message = duplicationException.Message };
            _logger.LogWarning(
                "{Timestamp} TraceId={TraceId} Event=DuplicateException Message={Message}",
                DateTimeOffset.UtcNow, traceId, duplicationException.Message);
        }
        else
        {
            context.Response.StatusCode = (int)HttpStatusCode.InternalServerError;
            errorBody = new { error = "internal_server_error", message = "An unexpected error occurred." };
            _logger.LogError(
                exception,
                "{Timestamp} TraceId={TraceId} Event=UnhandledException Message={Message}",
                DateTimeOffset.UtcNow, traceId, exception.Message);
        }

        var json = JsonSerializer.Serialize(errorBody);
        await context.Response.WriteAsync(json);
    }
}
