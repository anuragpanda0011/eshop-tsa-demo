using BlazorShared;
using Microsoft.Extensions.Diagnostics.HealthChecks;
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
            _logger.LogInformation("ApiHealthCheck probing url={Url}", url);

            var client = _httpClientFactory.CreateClient("healthcheck");
            var response = await client.GetAsync(url, cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning(
                    "ApiHealthCheck received non-success status={Status}", response.StatusCode);
                return HealthCheckResult.Unhealthy(
                    $"API returned status {response.StatusCode}");
            }

            var pageContents = await response.Content.ReadAsStringAsync(cancellationToken);
            if (pageContents.Contains(".NET Bot Black Sweatshirt"))
            {
                _logger.LogInformation("ApiHealthCheck healthy");
                return HealthCheckResult.Healthy("The check indicates a healthy result.");
            }

            _logger.LogWarning("ApiHealthCheck unhealthy: sentinel product not found");
            return HealthCheckResult.Unhealthy("The check indicates an unhealthy result.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "ApiHealthCheck threw an exception");
            return HealthCheckResult.Unhealthy("Exception during health check", ex);
        }
    }
}
