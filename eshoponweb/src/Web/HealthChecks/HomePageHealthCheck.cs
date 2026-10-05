using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.Web.HealthChecks;

public class HomePageHealthCheck : IHealthCheck
{
    private readonly IHttpContextAccessor _httpContextAccessor;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<HomePageHealthCheck> _logger;

    public HomePageHealthCheck(
        IHttpContextAccessor httpContextAccessor,
        IHttpClientFactory httpClientFactory,
        ILogger<HomePageHealthCheck> logger)
    {
        _httpContextAccessor = httpContextAccessor;
        _httpClientFactory = httpClientFactory;
        _logger = logger;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var request = _httpContextAccessor.HttpContext?.Request;
            if (request == null)
            {
                return HealthCheckResult.Unhealthy("No HTTP context available.");
            }

            // Always use HTTPS for health-check probes in production
            var scheme = request.IsHttps || IsProduction() ? "https" : request.Scheme;
            var url = $"{scheme}://{request.Host}";

            var client = _httpClientFactory.CreateClient("healthcheck");
            var response = await client.GetAsync(url, cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning(
                    "Home page health check received non-success status {StatusCode} from '{Url}'.",
                    response.StatusCode,
                    url);
                return HealthCheckResult.Unhealthy($"Home page returned {response.StatusCode}.");
            }

            var pageContents = await response.Content.ReadAsStringAsync(cancellationToken);
            if (pageContents.Contains(".NET Bot Black Sweatshirt"))
            {
                return HealthCheckResult.Healthy("The check indicates a healthy result.");
            }

            _logger.LogWarning("Home page health check content did not match expected content from '{Url}'.", url);
            return HealthCheckResult.Unhealthy("The check indicates an unhealthy result.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Home page health check threw an exception.");
            return HealthCheckResult.Unhealthy("Health check exception.", ex);
        }
    }

    private static bool IsProduction()
    {
        var env = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT");
        return string.Equals(env, "Production", StringComparison.OrdinalIgnoreCase);
    }
}
