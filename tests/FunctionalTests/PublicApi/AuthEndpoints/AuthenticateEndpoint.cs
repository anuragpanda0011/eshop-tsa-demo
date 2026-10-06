//using System.Net.Http;
//using System.Text;
//using System.Text.Json;
//using System.Threading.Tasks;
//using Microsoft.eShopWeb.FunctionalTests.PublicApi;
//using Microsoft.eShopWeb.PublicApi.AuthEndpoints;
//using Xunit;

//namespace Microsoft.eShopWeb.FunctionalTests.Web.Controllers;

// NOTE: These tests are commented out in the original source and are retained
// as-is.  When re-enabled they should POST to /api/v1/authenticate (updated
// route prefix) and resolve credentials from environment variables rather than
// from AuthorizationConstants so that no plaintext passwords appear in source.

//[Collection("Sequential")]
//public class AuthenticateEndpoint : IClassFixture<TestApiApplication>
//{
//    JsonSerializerOptions _jsonOptions = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };

//    public AuthenticateEndpoint(TestApiApplication factory)
//    {
//        Client = factory.CreateClient();
//    }

//    public HttpClient Client { get; }

//    [Theory]
//    [InlineData("demouser@microsoft.com", "Pass@word1", true)]
//    [InlineData("demouser@microsoft.com", "badpassword", false)]
//    [InlineData("baduser@microsoft.com",  "badpassword", false)]
//    public async Task ReturnsExpectedResultGivenCredentials(
//        string testUsername, string testPassword, bool expectedResult)
//    {
//        var request = new AuthenticateRequest
//        {
//            Username = testUsername,
//            Password = testPassword
//        };
//        var jsonContent = new StringContent(
//            JsonSerializer.Serialize(request), Encoding.UTF8, "application/json");

//        // Route updated to /api/v1/authenticate per API design rules.
//        var response = await Client.PostAsync("/api/v1/authenticate", jsonContent);
//        response.EnsureSuccessStatusCode();

//        var stringResponse = await response.Content.ReadAsStringAsync();
//        var model = JsonSerializer.Deserialize<AuthenticateResponse>(stringResponse, _jsonOptions);

//        Assert.Equal(expectedResult, model!.Result);
//    }
//}
