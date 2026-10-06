// Functional tests for the AuthenticateEndpoint are intentionally kept as
// integration-style tests that require a running test host. The tests below
// exercise the /api/v1/authenticate route against the in-memory TestApiApplication
// fixture so that no real database or secret store is required in CI.

using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.eShopWeb.FunctionalTests.PublicApi;
using Microsoft.eShopWeb.PublicApi.AuthEndpoints;
using Xunit;

namespace Microsoft.eShopWeb.FunctionalTests.Web.Controllers;

[Collection("Sequential")]
public class AuthenticateEndpointTests : IClassFixture<TestApiApplication>
{
    private static readonly JsonSerializerOptions JsonOptions =
        new JsonSerializerOptions { PropertyNameCaseInsensitive = true };

    public AuthenticateEndpointTests(TestApiApplication factory)
    {
        Client = factory.CreateClient();
    }

    public HttpClient Client { get; }

    [Theory]
    [InlineData("buyer@eshoponweb.com", "Pass@word1", true)]
    [InlineData("buyer@eshoponweb.com", "badpassword", false)]
    [InlineData("baduser@microsoft.com", "badpassword", false)]
    public async Task ReturnsExpectedResultGivenCredentials(
        string testUsername,
        string testPassword,
        bool expectedResult)
    {
        var request = new AuthenticateRequest
        {
            Username = testUsername,
            Password = testPassword
        };

        var jsonContent = new StringContent(
            JsonSerializer.Serialize(request),
            Encoding.UTF8,
            "application/json");

        // Route updated to /api/v1/ prefix per API design rules
        var response = await Client.PostAsync("/api/v1/authenticate", jsonContent);
        response.EnsureSuccessStatusCode();

        var stringResponse = await response.Content.ReadAsStringAsync();
        var model = JsonSerializer.Deserialize<AuthenticateResponse>(stringResponse, JsonOptions);

        Assert.NotNull(model);
        Assert.Equal(expectedResult, model!.Result);
    }
}
