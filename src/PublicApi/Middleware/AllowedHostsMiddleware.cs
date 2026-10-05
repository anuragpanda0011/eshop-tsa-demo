using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopOnWeb.PublicApi.Middleware;

/// <summary>
/// Validates the Host header against an explicit allowlist.
/// Register before routing in PublicApi Program.cs.
/// </summary>
public sealed class AllowedHostsMiddleware
{
    private readonly RequestDelegate                 _next;
    private readonly IReadOnlyList<string>           _allowedHosts;
    private readonly ILogger<AllowedHostsMiddleware> _logger;
    private readonly bool                            _disabled;

    public AllowedHostsMiddleware(
        RequestDelegate                    next,
        IEnumerable<string>                allowedHosts,
        ILogger<AllowedHostsMiddleware>    logger,
        bool                               disabled = false)
    {
        _next         = next;
        _allowedHosts = allowedHosts?.ToList() ?? throw new ArgumentNullException(nameof(allowedHosts));
        _logger       = logger;
        _disabled     = disabled;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        if (_disabled) { await _next(context); return; }

        var host    = context.Request.Host.Host;
        var allowed = _allowedHosts.Any(h =>
            string.Equals(h, host, StringComparison.OrdinalIgnoreCase) ||
            (h.StartsWith("*.", StringComparison.Ordinal) &&
             host.EndsWith(h[1..], StringComparison.OrdinalIgnoreCase)));

        if (!allowed)
        {
            _logger.LogWarning("Rejected request with Host='{Host}'", host);
            context.Response.StatusCode = StatusCodes.Status400BadRequest;
            await context.Response.WriteAsync("Bad Request — invalid host header.");
            return;
        }

        await _next(context);
    }
}
