using System.Net;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace Microsoft.eShopWeb.FunctionalTests.Web.Controllers;

/// <summary>
/// Functional tests for the Identity / Account sign-in flow.
///
/// Passwords used here match the seed data loaded into the in-memory database
/// by WebTestFixture.  They must NOT be stored as plaintext in production;
/// in the running application they are stored as bcrypt/ASP.NET Identity hashes.
/// </summary>
[Collection("Sequential")]
public class AccountControllerSignIn : IClassFixture<TestApplication>
{
    // Seed credentials injected by the in-memory test database.
    // In production, credentials are managed by Azure Key Vault + ASP.NET Identity.
    private const string DemoUserEmail    = "demouser@microsoft.com";
    private const string DemoUserPassword = "Pass@word1";

    public AccountControllerSignIn(TestApplication factory)
    {
        Client = factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            AllowAutoRedirect = false
        });
    }

    public HttpClient Client { get; }

    [Fact]
    public async Task ReturnsSignInScreenOnGet()
    {
        var response = await Client.GetAsync("/identity/account/login");
        response.EnsureSuccessStatusCode();
        var stringResponse = await response.Content.ReadAsStringAsync();

        Assert.Contains(DemoUserEmail, stringResponse);
    }

    [Fact]
    public void RegexMatchesValidRequestVerificationToken()
    {
        // TODO: Move to a unit test
        var input = @"<input name=""__RequestVerificationToken"" type=""hidden"" value=""CfDJ8Obhlq65OzlDkoBvsSX0tgxFUkIZ_qDDSt49D_StnYwphIyXO4zxfjopCWsygfOkngsL6P0tPmS2HTB1oYW-p_JzE0_MCFb7tF9Ol_qoOg_IC_yTjBNChF0qRgoZPmKYOIJigg7e2rsBsmMZDTdbnGo"" /><input name=""RememberMe"" type=""hidden"" value=""false"" /></form>";
        const string regexpression = @"name=""__RequestVerificationToken"" type=""hidden"" value=""([-A-Za-z0-9+=/\\_]+?)""";
        var regex = new Regex(regexpression);
        var match = regex.Match(input);
        var group = match.Groups.Values.LastOrDefault();
        Assert.NotNull(group);
        Assert.True(group.Value.Length > 50);
    }

    [Fact]
    public async Task ReturnsFormWithRequestVerificationToken()
    {
        var response = await Client.GetAsync("/identity/account/login");
        response.EnsureSuccessStatusCode();
        var stringResponse = await response.Content.ReadAsStringAsync();

        string token = WebPageHelpers.GetRequestVerificationToken(stringResponse);
        Assert.True(token.Length > 50);
    }

    [Fact]
    public async Task ReturnsSuccessfulSignInOnPostWithValidCredentials()
    {
        var getResponse = await Client.GetAsync("/identity/account/login");
        getResponse.EnsureSuccessStatusCode();
        var stringResponse1 = await getResponse.Content.ReadAsStringAsync();

        var keyValues = new List<KeyValuePair<string, string>>
        {
            new("Email",    DemoUserEmail),
            new("Password", DemoUserPassword),
            new(WebPageHelpers.TokenTag, WebPageHelpers.GetRequestVerificationToken(stringResponse1))
        };
        var formContent = new FormUrlEncodedContent(keyValues);

        var postResponse = await Client.PostAsync("/identity/account/login", formContent);
        Assert.Equal(HttpStatusCode.Redirect, postResponse.StatusCode);
        Assert.Equal(new Uri("/", UriKind.Relative), postResponse.Headers.Location);
    }

    [Fact]
    public async Task UpdatePhoneNumberProfile()
    {
        // ── Login ────────────────────────────────────────────────────────────
        var getResponse = await Client.GetAsync("/identity/account/login");
        getResponse.EnsureSuccessStatusCode();
        var stringResponse1 = await getResponse.Content.ReadAsStringAsync();

        var loginValues = new List<KeyValuePair<string, string>>
        {
            new("Email",    DemoUserEmail),
            new("Password", DemoUserPassword),
            new(WebPageHelpers.TokenTag, WebPageHelpers.GetRequestVerificationToken(stringResponse1))
        };
        await Client.PostAsync("/identity/account/login", new FormUrlEncodedContent(loginValues));

        // ── Profile page ─────────────────────────────────────────────────────
        var profileResponse = await Client.GetAsync("/manage/my-account");
        profileResponse.EnsureSuccessStatusCode();
        var stringProfileResponse = await profileResponse.Content.ReadAsStringAsync();

        // ── Update phone number ───────────────────────────────────────────────
        var updateProfileValues = new List<KeyValuePair<string, string>>
        {
            new("Email",       DemoUserEmail),
            new("PhoneNumber", "03656565"),
            new(WebPageHelpers.TokenTag, WebPageHelpers.GetRequestVerificationToken(stringProfileResponse))
        };
        var postProfileResponse = await Client.PostAsync(
            "/manage/my-account", new FormUrlEncodedContent(updateProfileValues));

        Assert.Equal(HttpStatusCode.Redirect, postProfileResponse.StatusCode);

        var profileResponse2       = await Client.GetAsync("/manage/my-account");
        var stringProfileResponse2 = await profileResponse2.Content.ReadAsStringAsync();
        Assert.Contains("03656565", stringProfileResponse2);
    }
}
