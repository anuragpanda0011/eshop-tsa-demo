using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using BlazorShared;
using BlazorShared.Models;
using Microsoft.Extensions.Options;

namespace BlazorAdmin.Services;

public class HttpService
{
    private static readonly JsonSerializerOptions _jsonOptions = new JsonSerializerOptions
    {
        PropertyNameCaseInsensitive = true
    };

    private readonly HttpClient _httpClient;
    private readonly ToastService _toastService;
    private readonly string _apiUrl;

    public HttpService(
        HttpClient httpClient,
        IOptions<BaseUrlConfiguration> baseUrlConfiguration,
        ToastService toastService)
    {
        _httpClient = httpClient;
        _toastService = toastService;
        _apiUrl = baseUrlConfiguration.Value.ApiBase;
    }

    public async Task<T> HttpGet<T>(string uri)
        where T : class
    {
        var result = await _httpClient.GetAsync($"{_apiUrl}{uri}");
        if (!result.IsSuccessStatusCode)
        {
            return null;
        }

        return await FromHttpResponseMessage<T>(result);
    }

    public async Task<T> HttpDelete<T>(string uri, int id)
        where T : class
    {
        var result = await _httpClient.DeleteAsync($"{_apiUrl}{uri}/{id}");
        if (!result.IsSuccessStatusCode)
        {
            return null;
        }

        return await FromHttpResponseMessage<T>(result);
    }

    public async Task<T> HttpPost<T>(string uri, object dataToSend)
        where T : class
    {
        var content = ToJson(dataToSend);
        var result = await _httpClient.PostAsync($"{_apiUrl}{uri}", content);

        if (!result.IsSuccessStatusCode)
        {
            var body = await result.Content.ReadAsStringAsync();
            try
            {
                var exception = JsonSerializer.Deserialize<ErrorDetails>(body, _jsonOptions);
                _toastService.ShowToast(
                    $"Error: {exception?.Message ?? result.ReasonPhrase}",
                    ToastLevel.Error);
            }
            catch
            {
                _toastService.ShowToast(
                    $"Error: {result.ReasonPhrase}",
                    ToastLevel.Error);
            }

            return null;
        }

        return await FromHttpResponseMessage<T>(result);
    }

    public async Task<T> HttpPut<T>(string uri, object dataToSend)
        where T : class
    {
        var content = ToJson(dataToSend);
        var result = await _httpClient.PutAsync($"{_apiUrl}{uri}", content);

        if (!result.IsSuccessStatusCode)
        {
            _toastService.ShowToast(
                $"Error: {result.ReasonPhrase}",
                ToastLevel.Error);
            return null;
        }

        return await FromHttpResponseMessage<T>(result);
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

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
        return JsonSerializer.Deserialize<T>(body, _jsonOptions);
    }
}
