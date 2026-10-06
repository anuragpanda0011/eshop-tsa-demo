using BlazorShared.Models;
using Microsoft.eShopWeb;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace PublicApiIntegrationTests.AuthEndpoints;

[TestClass]
public class CreateCatalogItemEndpointTest
{
    private readonly int _testBrandId = 1;
    private readonly int _testTypeId = 2;
    private readonly string _testDescription = "test description";
    private readonly string _testName = "test name";
    private readonly decimal _testPrice = 1.23m;

    [TestMethod]
    public async Task ReturnsNotAuthorizedGivenNormalUserToken()
    {
        var jsonContent = GetValidNewItemJson();
        var token = ApiTokenHelper.GetNormalUserToken();
        var client = ProgramTest.NewClient;
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", token);

        // Route updated to /api/v1/ prefix.
        var response = await client.PostAsync("api/v1/catalog-items", jsonContent);

        Assert.AreEqual(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [TestMethod]
    public async Task ReturnsSuccessGivenValidNewItemAndAdminUserToken()
    {
        var jsonContent = GetValidNewItemJson();
        var adminToken = ApiTokenHelper.GetAdminUserToken();
        var client = ProgramTest.NewClient;
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", adminToken);

        // Supply an idempotency key so the endpoint can deduplicate retried requests.
        client.DefaultRequestHeaders.TryAddWithoutValidation(
            "X-Idempotency-Key",
            System.Guid.NewGuid().ToString());

        // Route updated to /api/v1/ prefix.
        var response = await client.PostAsync("api/v1/catalog-items", jsonContent);
        response.EnsureSuccessStatusCode();

        var stringResponse = await response.Content.ReadAsStringAsync();
        var model = stringResponse.FromJson<CreateCatalogItemResponse>();

        Assert.IsNotNull(model, "Response body could not be deserialized.");
        Assert.AreEqual(_testBrandId, model!.CatalogItem.CatalogBrandId);
        Assert.AreEqual(_testTypeId, model.CatalogItem.CatalogTypeId);
        Assert.AreEqual(_testDescription, model.CatalogItem.Description);
        Assert.AreEqual(_testName, model.CatalogItem.Name);
        Assert.AreEqual(_testPrice, model.CatalogItem.Price);
    }

    private StringContent GetValidNewItemJson()
    {
        var request = new CreateCatalogItemRequest
        {
            CatalogBrandId = _testBrandId,
            CatalogTypeId = _testTypeId,
            Description = _testDescription,
            Name = _testName,
            Price = _testPrice
        };

        return new StringContent(
            JsonSerializer.Serialize(request),
            Encoding.UTF8,
            "application/json");
    }
}
