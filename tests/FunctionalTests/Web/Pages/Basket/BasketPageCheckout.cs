using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace Microsoft.eShopWeb.FunctionalTests.Web.Pages.Basket;

[Collection("Sequential")]
public class BasketPageCheckout : IClassFixture<TestApplication>
{
    public BasketPageCheckout(TestApplication factory)
    {
        Client = factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            AllowAutoRedirect = true
        });
    }

    public HttpClient Client { get; }

    [Fact]
    public async Task RedirectsToLoginIfNotAuthenticated()
    {
        // Load Home Page
        var response = await Client.GetAsync("/");
        response.EnsureSuccessStatusCode();
        var stringResponse1 = await response.Content.ReadAsStringAsync();

        string token = WebPageHelpers.GetRequestVerificationToken(stringResponse1);

        // Add Item to Cart
        var keyValues = new List<KeyValuePair<string, string>>
        {
            new("id",    "2"),
            new("name",  "shirt"),
            new("price", "19.49"),
            new("__RequestVerificationToken", token)
        };
        var formContent  = new FormUrlEncodedContent(keyValues);
        var postResponse = await Client.PostAsync("/basket/index", formContent);
        postResponse.EnsureSuccessStatusCode();
        var stringResponse = await postResponse.Content.ReadAsStringAsync();
        Assert.Contains(".NET Black &amp; White Mug", stringResponse);

        keyValues.Clear();
        var postResponse2 = await Client.PostAsync("/Basket/Checkout", new FormUrlEncodedContent(keyValues));
        Assert.Contains("/Identity/Account/Login", postResponse2!.RequestMessage!.RequestUri!.ToString()!);
    }
}
