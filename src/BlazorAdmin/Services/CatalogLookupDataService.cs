using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Net.Http.Json;
using System.Reflection;
using System.Threading.Tasks;
using BlazorShared;
using BlazorShared.Attributes;
using BlazorShared.Interfaces;
using BlazorShared.Models;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace BlazorAdmin.Services;

public class CatalogLookupDataService<TLookupData, TReponse>
    : ICatalogLookupDataService<TLookupData>
    where TLookupData : LookupData
    where TReponse : ILookupDataResponse<TLookupData>
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<CatalogLookupDataService<TLookupData, TReponse>> _logger;
    private readonly string _apiUrl;

    public CatalogLookupDataService(
        HttpClient httpClient,
        IOptions<BaseUrlConfiguration> baseUrlConfiguration,
        ILogger<CatalogLookupDataService<TLookupData, TReponse>> logger)
    {
        _httpClient = httpClient;
        _logger = logger;

        var cfg = baseUrlConfiguration?.Value
            ?? throw new ArgumentNullException(nameof(baseUrlConfiguration));

        _apiUrl = cfg.ApiBase
            ?? throw new InvalidOperationException(
                "BaseUrlConfiguration.ApiBase is not configured.");
    }

    public async Task<List<TLookupData>> List()
    {
        var endpointAttr = typeof(TLookupData).GetCustomAttribute<EndpointAttribute>();
        if (endpointAttr is null)
        {
            throw new InvalidOperationException(
                $"Type {typeof(TLookupData).Name} is missing the [Endpoint] attribute.");
        }

        var endpointName = endpointAttr.Name;

        _logger.LogInformation(
            "{{\"event\":\"lookup_list\",\"type\":\"{TypeName}\",\"endpoint\":\"{Endpoint}\"}}",
            typeof(TLookupData).Name,
            endpointName);

        try
        {
            var response = await _httpClient.GetFromJsonAsync<TReponse>(
                $"{_apiUrl}{endpointName}");

            return response?.List ?? new List<TLookupData>();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "{{\"event\":\"lookup_list_error\",\"type\":\"{TypeName}\",\"endpoint\":\"{Endpoint}\"}}",
                typeof(TLookupData).Name,
                endpointName);
            throw;
        }
    }
}
