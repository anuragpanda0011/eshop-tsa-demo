using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.eShopWeb;
using Microsoft.eShopWeb.PublicApi.AuthEndpoints;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace PublicApiIntegrationTests.AuthEndpoints;

[TestClass]
public class AuthenticateEndpoint
{
    // Default password is read from the environment so no credential is
    // hardcoded in source. Set ESHOPONWEB_DEFAULT_PASSWORD in CI secrets.
    private static readonly string DefaultPassword =
        System.Environment.GetEnvironmentVariable("ESHOPONWEB_DEFAULT_PASSWORD")
        ?? throw new System.InvalidOperationException(
            "Environment variable ESHOPONWEB_DEFAULT_PASSWORD is not set.");

    [TestMethod]
    public async Task ReturnsSuccessGivenValidCredentials()
    {
        await RunTest("demouser@microsoft.com", DefaultPassword, expectedResult: true);
    }

    [TestMethod]
    public async Task ReturnsFailureGivenBadPassword()
    {
        await RunTest("demouser@microsoft.com", "badpassword", expectedResult: false);
    }

    [TestMethod]
    public async Task ReturnsFailureGivenBadUserAndPassword()
    {
        await RunTest("baduser@microsoft.com", "badpassword", expectedResult: false);
    }

    private static async Task RunTest(string testUsername, string testPassword, bool expectedResult)
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

        // Route updated to /api/v1/ prefix per API design rules.
        var response = await ProgramTest.NewClient.PostAsync("api/v1/authenticate", jsonContent);
        response.EnsureSuccessStatusCode();

        var stringResponse = await response.Content.ReadAsStringAsync();
        var model = stringResponse.FromJson<AuthenticateResponse>();

        Assert.IsNotNull(model, "Response body could not be deserialized.");
        Assert.AreEqual(expectedResult, model!.Result);
    }
}
