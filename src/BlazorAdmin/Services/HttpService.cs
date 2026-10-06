using System;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using BlazorShared;
using BlazorShared.Models;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace BlazorAdmin.Services;

public class HttpService
{
    private readonly HttpClient _httpClient;
    private readonly ToastService _toastService;
    private readonly ILogger<HttpService> _logger;
    private readonly string _apiUrl;

    private static readonly JsonSerializerOptions JsonOptions = new JsonSerializerOptions
    {
        PropertyNameCaseInsensitive = true
    };

    public HttpService(
        HttpClient httpClient,
        IOptions<BaseUrlConfiguration> baseUrlConfiguration,
        ToastService toastService,
        ILogger<HttpService> logger)
    {
        _httpClient = httpClient;
        _toastService = toastService;
        _logger = logger;

        var cfg = baseUrlConfiguration?.Value
            ?? throw new ArgumentNullException(nameof(baseUrlConfiguration));

        _apiUrl = cfg.ApiBase
            ?? throw new InvalidOperationException(
                "BaseUrlConfiguration.ApiBase is not configured.");
    }

    public async Task<T> HttpGet<T>(string uri)
        where T : class
    {
        _logger.LogInformation("{{\"event\":\"http_get\",\"uri\":\"{Uri}\"}}", uri);

        var result = await _httpClient.GetAsync($"{_apiUrl}{uri}");
        if (!result.IsSuccessStatusCode)
        {
            _logger.LogWarning(
                "{{\"event\":\"http_get_failed\",\"uri\":\"{Uri}\",\"status\":{Status}}}",
                uri, (int)result.StatusCode);
            return null;
        }

        return await FromHttpResponseMessage<T>(result);
    }

    public async Task<T> HttpDelete<T>(string uri, int id)
        where T : class
    {
        _logger.LogInformation(
            "{{\"event\":\"http_delete\",\"uri\":\"{Uri}\",\"id\":{Id}}}",
            uri, id);

        var result = await _httpClient.DeleteAsync($"{_apiUrl}{uri}/{id}");
        if (!result.IsSuccessStatusCode)
        {
            _logger.LogWarning(
                "{{\"event\":\"http_delete_failed\",\"uri\":\"{Uri}\",\"id\":{Id},\"status\":{Status}}}",
                uri, id, (int)result.StatusCode);
            return null;
        }

        return await FromHttpResponseMessage<T>(result);
    }

    public async Task<T> HttpPost<T>(string uri, object dataToSend)
        where T : class
    {
        _logger.LogInformation("{{\"event\":\"http_post\",\"uri\":\"{Uri}\"}}", uri);

        var content = ToJson(dataToSend);
        var result = await _httpClient.PostAsync($"{_apiUrl}{uri}", content);

        if (!result.IsSuccessStatusCode)
        {
            _logger.LogWarning(
                "{{\"event\":\"http_post_failed\",\"uri\":\"{Uri}\",\"status\":{Status}}}",
                uri, (int)result.StatusCode);

            try
            {
                var body = await result.Content.ReadAsStringAsync();
                var exception = JsonSerializer.Deserialize<ErrorDetails>(body, JsonOptions);
                _toastService.ShowToast(
                    $"Error: {exception?.Message ?? result.ReasonPhrase}",
                    ToastLevel.Error);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex,
                    "{{\"event\":\"http_post_error_parse_failed\",\"uri\":\"{Uri}\"}}",
                    uri);
                _toastService.ShowToast($"Error: {result.ReasonPhrase}", ToastLevel.Error);
            }

            return null;
        }

        return await FromHttpResponseMessage<T>(result);
    }

    public async Task<T> HttpPut<T>(string uri, object dataToSend)
        where T : class
    {
        _logger.LogInformation("{{\"event\":\"http_put\",\"uri\":\"{Uri}\"}}", uri);

        var content = ToJson(dataToSend);
        var result = await _httpClient.PutAsync($"{_apiUrl}{uri}", content);

        if (!result.IsSuccessStatusCode)
        {
            _logger.LogWarning(
                "{{\"event\":\"http_put_failed\",\"uri\":\"{Uri}\",\"status\":{Status}}}",
                uri, (int)result.StatusCode);
            _toastService.ShowToast($"Error: {result.ReasonPhrase}", ToastLevel.Error);
            return null;
        }

        return await FromHttpResponseMessage<T>(result);
    }

    private static StringContent ToJson(object obj)
    {
        return new StringContent(
            JsonSerializer.Serialize(obj),
            Encoding.UTF8,
            "application/json");
    }

    private static async Task<T> FromHttpResponseMessage<T>(HttpResponseMessage result)
    {
        var body = await result.Content.ReadAsStringAsync();
        return JsonSerializer.Deserialize<T>(body, JsonOptions);
    }
}
