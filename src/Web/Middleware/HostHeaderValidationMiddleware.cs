using System;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Microsoft.eShopOnWeb.Web.Middleware;

/// <summary>
/// Rejects requests whose Host header does not appear in the configured
/// AllowedHosts list.  This is a defence-in-depth layer on top of
/// ASP.NET Core's built-in host filtering middleware.
/// </summary>
public sealed class HostHeaderValidationMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<HostHeaderValidationMiddleware> _logger;
    private readonly string[] _allowedHosts;

    public HostHeaderValidationMiddleware(
        RequestDelegate next,
        ILogger<HostHeaderValidationMiddleware> logger,
        string[] allowedHosts)
    {
        _next         = next ?? throw new ArgumentNullException(nameof(next));
        _logger       = logger ?? throw new ArgumentNullException(nameof(logger));
        _allowedHosts = allowedHosts ?? Array.Empty<string>();
    }

    public async Task InvokeAsync(HttpContext context)
    {
        if (_allowedHosts.Length > 0)
        {
            string? requestHost = context.Request.Host.Host;

            bool isAllowed = _allowedHosts.Any(h =>
                string.Equals(h, requestHost, StringComparison.OrdinalIgnoreCase) ||
                h == "*");

            if (!isAllowed)
            {
                _logger.LogWarning(
                    "Rejected request with disallowed Host header '{Host}' from {RemoteIp}",
                    requestHost,
                    context.Connection.RemoteIpAddress);

                context.Response.StatusCode = StatusCodes.Status400BadRequest;
                await context.Response.WriteAsync("Invalid Host header.");
                return;
            }
        }

        await _next(context);
    }
}
