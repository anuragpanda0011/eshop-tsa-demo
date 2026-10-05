using System;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.eShopWeb.PublicApi.AuthEndpoints;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace PublicApiIntegrationTests.AuthEndpoints;

[TestClass]
public class AuthenticateEndpointTest
{
    // Default password is read from the environment — never hardcoded.
    private static readonly string DefaultPassword =
        Environment.GetEnvironmentVariable("TEST_DEFAULT_PASSWORD")
        ?? throw new InvalidOperationException(
            "TEST_DEFAULT_PASSWORD environment variable is required for integration tests.");

    private static readonly JsonSerializerOptions JsonOptions =
        new JsonSerializerOptions { PropertyNameCaseInsensitive = true };

    [TestMethod]
    [DataRow("demouser@microsoft.com", true)]   // valid password supplied via env var
    [DataRow("demouser@microsoft.com", false)]  // bad password
    [DataRow("baduser@microsoft.com", false)]   // bad user + bad password
    public async Task ReturnsExpectedResultGivenCredentials(
        string testUsername,
        bool expectedResult)
    {
        // Choose a valid or obviously invalid password based on the expected result.
        string testPassword = expectedResult
            ? DefaultPassword
            : "badpassword-that-will-never-match";

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
        var response = await ProgramTest.NewClient.PostAsync("/api/v1/authenticate", jsonContent);
        response.EnsureSuccessStatusCode();

        var stringResponse = await response.Content.ReadAsStringAsync();
        var model = JsonSerializer.Deserialize<AuthenticateResponse>(stringResponse, JsonOptions);

        Assert.IsNotNull(model);
        Assert.AreEqual(expectedResult, model!.Result);
    }
}
