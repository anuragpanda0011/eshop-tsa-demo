using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace Microsoft.eShopWeb.FunctionalTests.Web.Pages.Basket;

[Collection("Sequential")]
public class IndexTest : IClassFixture<TestApplication>
{
    public IndexTest(TestApplication factory)
    {
        Client = factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            AllowAutoRedirect = true
        });
    }

    public HttpClient Client { get; }

    [Fact]
    public async Task OnPostUpdateTo50Successfully()
    {
        // ── Load Home Page ────────────────────────────────────────────────────
        var response = await Client.GetAsync("/");
        response.EnsureSuccessStatusCode();
        var stringResponse1 = await response.Content.ReadAsStringAsync();
        string token = WebPageHelpers.GetRequestVerificationToken(stringResponse1);

        // ── Add Item to Cart ──────────────────────────────────────────────────
        var keyValues = new List<KeyValuePair<string, string>>
        {
            new("id",   "2"),
            new("name", "shirt"),
            new("__RequestVerificationToken", token)
        };
        var postResponse = await Client.PostAsync("/basket/index", new FormUrlEncodedContent(keyValues));
        postResponse.EnsureSuccessStatusCode();
        var stringResponse = await postResponse.Content.ReadAsStringAsync();
        Assert.Contains(".NET Black &amp; White Mug", stringResponse);

        // ── Update quantity ───────────────────────────────────────────────────
        var updateKeyValues = new List<KeyValuePair<string, string>>
        {
            new("Items[0].Id",       WebPageHelpers.GetId(stringResponse)),
            new("Items[0].Quantity", "49"),
            new(WebPageHelpers.TokenTag, WebPageHelpers.GetRequestVerificationToken(stringResponse))
        };
        var updateResponse       = await Client.PostAsync("/basket/update", new FormUrlEncodedContent(updateKeyValues));
        var stringUpdateResponse = await updateResponse.Content.ReadAsStringAsync();

        Assert.Contains("/basket/update", updateResponse!.RequestMessage!.RequestUri!.ToString()!);
        decimal expectedTotalAmount = 416.50M;
        Assert.Contains(expectedTotalAmount.ToString("N2"), stringUpdateResponse);
    }

    [Fact]
    public async Task OnPostUpdateTo0EmptyBasket()
    {
        // ── Load Home Page ────────────────────────────────────────────────────
        var response = await Client.GetAsync("/");
        response.EnsureSuccessStatusCode();
        var stringResponse1 = await response.Content.ReadAsStringAsync();
        string token = WebPageHelpers.GetRequestVerificationToken(stringResponse1);

        // ── Add Item to Cart ──────────────────────────────────────────────────
        var keyValues = new List<KeyValuePair<string, string>>
        {
            new("id",   "2"),
            new("name", "shirt"),
            new("__RequestVerificationToken", token)
        };
        var postResponse = await Client.PostAsync("/basket/index", new FormUrlEncodedContent(keyValues));
        postResponse.EnsureSuccessStatusCode();
        var stringResponse = await postResponse.Content.ReadAsStringAsync();
        Assert.Contains(".NET Black &amp; White Mug", stringResponse);

        // ── Update quantity to 0 (should empty basket) ────────────────────────
        var updateKeyValues = new List<KeyValuePair<string, string>>
        {
            new("Items[0].Id",       WebPageHelpers.GetId(stringResponse)),
            new("Items[0].Quantity", "0"),
            new(WebPageHelpers.TokenTag, WebPageHelpers.GetRequestVerificationToken(stringResponse))
        };
        var updateResponse       = await Client.PostAsync("/basket/update", new FormUrlEncodedContent(updateKeyValues));
        var stringUpdateResponse = await updateResponse.Content.ReadAsStringAsync();

        Assert.Contains("/basket/update", updateResponse!.RequestMessage!.RequestUri!.ToString()!);
        Assert.Contains("Basket is empty", stringUpdateResponse);
    }
}
