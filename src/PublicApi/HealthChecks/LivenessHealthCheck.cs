using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace Microsoft.eShopOnWeb.PublicApi.HealthChecks;

/// <summary>
/// Simple liveness check for the PublicApi process.
/// </summary>
public sealed class LivenessHealthCheck : IHealthCheck
{
    public Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
        => Task.FromResult(HealthCheckResult.Healthy("OK"));
}
