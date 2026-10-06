using Microsoft.Extensions.Diagnostics.HealthChecks;

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
                _logger.LogWarning("HomePageHealthCheck: HttpContext not available");
                return HealthCheckResult.Unhealthy("HttpContext not available");
            }

            var url = $"{request.Scheme}://{request.Host}";
            _logger.LogInformation("HomePageHealthCheck probing url={Url}", url);

            var client = _httpClientFactory.CreateClient("healthcheck");
            var response = await client.GetAsync(url, cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning(
                    "HomePageHealthCheck received non-success status={Status}", response.StatusCode);
                return HealthCheckResult.Unhealthy(
                    $"Home page returned status {response.StatusCode}");
            }

            var pageContents = await response.Content.ReadAsStringAsync(cancellationToken);
            if (pageContents.Contains(".NET Bot Black Sweatshirt"))
            {
                _logger.LogInformation("HomePageHealthCheck healthy");
                return HealthCheckResult.Healthy("The check indicates a healthy result.");
            }

            _logger.LogWarning("HomePageHealthCheck unhealthy: sentinel product not found");
            return HealthCheckResult.Unhealthy("The check indicates an unhealthy result.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "HomePageHealthCheck threw an exception");
            return HealthCheckResult.Unhealthy("Exception during health check", ex);
        }
    }
}
