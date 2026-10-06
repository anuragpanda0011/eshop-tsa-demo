using System;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Logging;
using StackExchange.Redis;

namespace Microsoft.eShopOnWeb.Web.HealthChecks;

/// <summary>
/// Readiness probe — verifies SQL Server and Redis connectivity.
/// Returns Degraded/Unhealthy if any dependency is unreachable so the
/// load balancer can stop routing traffic to this instance.
/// </summary>
public sealed class ReadyHealthCheck : IHealthCheck
{
    private readonly string _catalogConnectionString;
    private readonly IConnectionMultiplexer _redis;
    private readonly ILogger<ReadyHealthCheck> _logger;

    public ReadyHealthCheck(
        string catalogConnectionString,
        IConnectionMultiplexer redis,
        ILogger<ReadyHealthCheck> logger)
    {
        _catalogConnectionString = catalogConnectionString;
        _redis  = redis;
        _logger = logger;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            // SQL check
            await using var conn = new SqlConnection(_catalogConnectionString);
            await conn.OpenAsync(cancellationToken);
            await using var cmd = conn.CreateCommand();
            cmd.CommandText = "SELECT 1";
            await cmd.ExecuteScalarAsync(cancellationToken);

            // Redis check
            IDatabase db = _redis.GetDatabase();
            await db.PingAsync();

            return HealthCheckResult.Healthy("All dependencies reachable.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Readiness check failed");
            return HealthCheckResult.Unhealthy("One or more dependencies are unreachable.", ex);
        }
    }
}
