using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using System.Linq;
using System.Text.Json;

namespace Microsoft.eShopOnWeb.Web.Extensions;

public static class HealthCheckExtensions
{
    public static IServiceCollection AddEShopHealthChecks(
        this IServiceCollection services,
        string catalogConnectionString,
        string redisConnectionString)
    {
        services.AddHealthChecks()
            .AddCheck<HealthChecks.LivenessHealthCheck>(
                "liveness",
                tags: new[] { "live" })
            .AddSqlServer(
                connectionString: catalogConnectionString,
                name: "catalog-db",
                failureStatus: HealthStatus.Degraded,
                tags: new[] { "ready", "db" })
            .AddRedis(
                redisConnectionString: redisConnectionString,
                name: "redis",
                failureStatus: HealthStatus.Degraded,
                tags: new[] { "ready", "cache" });

        return services;
    }

    public static IApplicationBuilder MapEShopHealthChecks(this WebApplication app)
    {
        // Liveness — returns 200 immediately if process is up
        app.MapHealthChecks("/health/live", new HealthCheckOptions
        {
            Predicate      = check => check.Tags.Contains("live"),
            AllowCachingResponses = false,
        });

        // Readiness — checks DB + Redis
        app.MapHealthChecks("/health/ready", new HealthCheckOptions
        {
            Predicate      = check => check.Tags.Contains("ready"),
            AllowCachingResponses = false,
            ResponseWriter = WriteJsonResponseAsync,
        });

        return app;
    }

    private static System.Threading.Tasks.Task WriteJsonResponseAsync(
        HttpContext ctx, HealthReport report)
    {
        ctx.Response.ContentType = "application/json";
        var result = JsonSerializer.Serialize(new
        {
            status = report.Status.ToString(),
            checks = report.Entries.Select(e => new
            {
                name        = e.Key,
                status      = e.Value.Status.ToString(),
                description = e.Value.Description,
                duration    = e.Value.Duration.TotalMilliseconds,
            }),
        });
        return ctx.Response.WriteAsync(result);
    }
}
