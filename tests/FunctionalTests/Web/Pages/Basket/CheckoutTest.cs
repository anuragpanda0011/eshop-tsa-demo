using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace Microsoft.eShopWeb.FunctionalTests.Web.Pages.Basket;

/// <summary>
/// End-to-end checkout flow test.
///
/// Credentials used here match the in-memory seed data.  In production they are
/// stored as ASP.NET Identity password hashes (bcrypt via PBKDF2); plaintext
/// values never leave the test harness.
/// </summary>
[Collection("Sequential")]
public class CheckoutTest : IClassFixture<TestApplication>
{
    private const string DemoUserEmail    = "demouser@microsoft.com";
    private const string DemoUserPassword = "Pass@word1";

    public CheckoutTest(TestApplication factory)
    {
        Client = factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            AllowAutoRedirect = true
        });
    }

    public HttpClient Client { get; }

    [Fact]
    public async Task SucessfullyPay()
    {
        // ── Load Home Page ────────────────────────────────────────────────────
        var response       = await Client.GetAsync("/");
        response.EnsureSuccessStatusCode();
        var stringResponse = await response.Content.ReadAsStringAsync();

        // ── Add Item to Cart ──────────────────────────────────────────────────
        var keyValues = new List<KeyValuePair<string, string>>
        {
            new("id",    "2"),
            new("name",  "shirt"),
            new("price", "19.49"),
            new(WebPageHelpers.TokenTag, WebPageHelpers.GetRequestVerificationToken(stringResponse))
        };
        var postResponse = await Client.PostAsync("/basket/index", new FormUrlEncodedContent(keyValues));
        postResponse.EnsureSuccessStatusCode();
        var stringPostResponse = await postResponse.Content.ReadAsStringAsync();
        Assert.Contains(".NET Black &amp; White Mug", stringPostResponse);

        // ── Login ─────────────────────────────────────────────────────────────
        var loginResponse = await Client.GetAsync("/Identity/Account/Login");
        var loginKeyValues = new List<KeyValuePair<string, string>>
        {
            new("email",    DemoUserEmail),
            new("password", DemoUserPassword),
            new(WebPageHelpers.TokenTag,
                WebPageHelpers.GetRequestVerificationToken(
                    await loginResponse.Content.ReadAsStringAsync()))
        };
        var loginPostResponse = await Client.PostAsync(
            "/Identity/Account/Login?ReturnUrl=%2FBasket%2FCheckout",
            new FormUrlEncodedContent(loginKeyValues));
        var loginStringResponse = await loginPostResponse.Content.ReadAsStringAsync();

        // ── Basket Checkout (Pay now) ─────────────────────────────────────────
        var checkOutKeyValues = new List<KeyValuePair<string, string>>
        {
            new("Items[0].Id",       "2"),
            new("Items[0].Quantity", "1"),
            new(WebPageHelpers.TokenTag, WebPageHelpers.GetRequestVerificationToken(loginStringResponse))
        };
        var checkOutResponse       = await Client.PostAsync("/basket/checkout", new FormUrlEncodedContent(checkOutKeyValues));
        var stringCheckOutResponse = await checkOutResponse.Content.ReadAsStringAsync();

        Assert.Contains("/Basket/Success", checkOutResponse.RequestMessage!.RequestUri!.ToString());
        Assert.Contains("Thanks for your Order!", stringCheckOutResponse);
    }
}
