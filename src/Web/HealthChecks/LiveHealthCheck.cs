using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace Microsoft.eShopOnWeb.Web.HealthChecks;

/// <summary>
/// Liveness probe — always returns Healthy if the process is running.
/// Used by the Docker HEALTHCHECK and Azure App Service health probe.
/// </summary>
public sealed class LiveHealthCheck : IHealthCheck
{
    public Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        return Task.FromResult(HealthCheckResult.Healthy("Process is alive."));
    }
}
