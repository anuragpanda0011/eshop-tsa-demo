using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Microsoft.eShopOnWeb.Web.Middleware;

/// <summary>
/// Validates the Host header on every incoming request against the
/// ALLOWED_HOSTS allowlist.  Returns 400 Bad Request for unknown hosts.
///
/// NOTE: ASP.NET Core ships its own AllowedHosts middleware
/// (WebHostDefaults.HostFilteringKey / UseHostFiltering) which does the same
/// thing — this class exists as an explicit, auditable enforcement layer.
/// Register it BEFORE routing: app.UseMiddleware&lt;AllowedHostsMiddleware&gt;()
/// </summary>
public sealed class AllowedHostsMiddleware
{
    private readonly RequestDelegate           _next;
    private readonly IReadOnlyList<string>     _allowedHosts;
    private readonly ILogger<AllowedHostsMiddleware> _logger;
    private readonly bool                      _disabled; // true only in dev/debug

    public AllowedHostsMiddleware(
        RequestDelegate                    next,
        IEnumerable<string>                allowedHosts,
        ILogger<AllowedHostsMiddleware>    logger,
        bool                               disabled = false)
    {
        _next         = next ?? throw new ArgumentNullException(nameof(next));
        _allowedHosts = allowedHosts?.ToList() ?? throw new ArgumentNullException(nameof(allowedHosts));
        _logger       = logger ?? throw new ArgumentNullException(nameof(logger));
        _disabled     = disabled;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        if (_disabled)
        {
            await _next(context);
            return;
        }

        var host = context.Request.Host.Host;

        var allowed = _allowedHosts.Any(h =>
            string.Equals(h, host, StringComparison.OrdinalIgnoreCase) ||
            (h.StartsWith("*.", StringComparison.Ordinal) &&
             host.EndsWith(h[1..], StringComparison.OrdinalIgnoreCase)));

        if (!allowed)
        {
            _logger.LogWarning(
                "Request rejected: Host header '{Host}' is not in ALLOWED_HOSTS.", host);
            context.Response.StatusCode = StatusCodes.Status400BadRequest;
            await context.Response.WriteAsync("Bad Request — invalid host header.");
            return;
        }

        await _next(context);
    }
}
