using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using BlazorShared;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Microsoft.eShopWeb.Web.HealthChecks;

public class ApiHealthCheck : IHealthCheck
{
    private readonly BaseUrlConfiguration _baseUrlConfiguration;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<ApiHealthCheck> _logger;

    public ApiHealthCheck(
        IOptions<BaseUrlConfiguration> baseUrlConfiguration,
        IHttpClientFactory httpClientFactory,
        ILogger<ApiHealthCheck> logger)
    {
        _baseUrlConfiguration = baseUrlConfiguration.Value;
        _httpClientFactory = httpClientFactory;
        _logger = logger;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var url = _baseUrlConfiguration.ApiBase + "catalog-items";
            var client = _httpClientFactory.CreateClient("healthcheck");
            var response = await client.GetAsync(url, cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning(
                    "API health check received non-success status {StatusCode} from '{Url}'.",
                    response.StatusCode,
                    url);
                return HealthCheckResult.Unhealthy($"API returned {response.StatusCode}.");
            }

            var pageContents = await response.Content.ReadAsStringAsync(cancellationToken);
            if (pageContents.Contains(".NET Bot Black Sweatshirt"))
            {
                return HealthCheckResult.Healthy("The check indicates a healthy result.");
            }

            _logger.LogWarning("API health check content did not match expected catalog items from '{Url}'.", url);
            return HealthCheckResult.Unhealthy("The check indicates an unhealthy result.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "API health check threw an exception.");
            return HealthCheckResult.Unhealthy("Health check exception.", ex);
        }
    }
}
