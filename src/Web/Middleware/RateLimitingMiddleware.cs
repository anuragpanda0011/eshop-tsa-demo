using System;
using System.Collections.Concurrent;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopOnWeb.Web.Middleware;

/// <summary>
/// Sliding-window IP-based rate limiter.
/// In production the sliding window state is backed by Azure Cache for Redis
/// so that all App Service instances share the same counters.
///
/// For simplicity this in-process implementation is used as the fallback when
/// Redis is unavailable; production deployments should wire in the Redis-backed
/// implementation via IDistributedCache.
/// </summary>
public sealed class RateLimitingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<RateLimitingMiddleware> _logger;
    private readonly int _maxRequests;
    private readonly TimeSpan _window;

    // ── In-process fallback counters ──────────────────────────────────────
    private static readonly ConcurrentDictionary<string, WindowCounter> _counters = new();

    public RateLimitingMiddleware(
        RequestDelegate next,
        ILogger<RateLimitingMiddleware> logger,
        int maxRequestsPerWindow = 300,
        int windowSeconds = 60)
    {
        _next        = next;
        _logger      = logger;
        _maxRequests = maxRequestsPerWindow;
        _window      = TimeSpan.FromSeconds(windowSeconds);
    }

    public async Task InvokeAsync(HttpContext context)
    {
        string clientKey = context.Connection.RemoteIpAddress?.ToString() ?? "unknown";

        WindowCounter counter = _counters.GetOrAdd(
            clientKey,
            _ => new WindowCounter());

        if (!counter.TryIncrement(_maxRequests, _window))
        {
            _logger.LogWarning("Rate limit exceeded for client {ClientKey}", clientKey);
            context.Response.StatusCode = StatusCodes.Status429TooManyRequests;
            context.Response.Headers.RetryAfter = _window.TotalSeconds.ToString("F0");
            await context.Response.WriteAsync("Too Many Requests");
            return;
        }

        await _next(context);
    }

    // ── Helpers ───────────────────────────────────────────────────────────
    private sealed class WindowCounter
    {
        private long _windowStart = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        private int  _count       = 0;

        public bool TryIncrement(int max, TimeSpan window)
        {
            long now          = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            long windowStart  = Interlocked.Read(ref _windowStart);
            long windowLength = (long)window.TotalSeconds;

            if (now - windowStart >= windowLength)
            {
                // Reset window
                if (Interlocked.CompareExchange(ref _windowStart, now, windowStart) == windowStart)
                    Interlocked.Exchange(ref _count, 0);
            }

            int current = Interlocked.Increment(ref _count);
            return current <= max;
        }
    }
}
