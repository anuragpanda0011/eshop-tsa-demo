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
        context.Response.ContentType = "application/json";

        string errorCode;
        string message;
        int statusCode;

        if (exception is DuplicateException duplicationException)
        {
            statusCode = (int)HttpStatusCode.Conflict;
            errorCode = "DUPLICATE_RESOURCE";
            message = duplicationException.Message;
        }
        else
        {
            statusCode = (int)HttpStatusCode.InternalServerError;
            errorCode = "INTERNAL_SERVER_ERROR";
            message = "An unexpected error occurred.";
        }

        context.Response.StatusCode = statusCode;

        _logger.LogError(exception,
            "Unhandled exception. StatusCode={StatusCode} ErrorCode={ErrorCode} TraceId={TraceId}",
            statusCode, errorCode, context.TraceIdentifier);

        var errorResponse = new
        {
            error = errorCode,
            message = message,
            traceId = context.TraceIdentifier
        };

        await context.Response.WriteAsync(JsonSerializer.Serialize(errorResponse));
    }
}
