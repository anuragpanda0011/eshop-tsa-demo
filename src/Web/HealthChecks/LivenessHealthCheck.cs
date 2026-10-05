using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace Microsoft.eShopOnWeb.Web.HealthChecks;

/// <summary>
/// Simple liveness check — confirms the process is alive and the HTTP
/// pipeline is responding.  Does NOT check downstream dependencies so that
/// Container Apps / App Service does not restart a healthy instance when a
/// database is temporarily unavailable.
/// </summary>
public sealed class LivenessHealthCheck : IHealthCheck
{
    public Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
        => Task.FromResult(HealthCheckResult.Healthy("OK"));
}
