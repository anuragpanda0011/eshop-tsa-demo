using BlazorShared.Models;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace PublicApiIntegrationTests.AuthEndpoints;

[TestClass]
public class CreateCatalogItemEndpointTest
{
    private readonly int _testBrandId = 1;
    private readonly int _testTypeId = 2;
    private readonly string _testDescription = "test description";
    private readonly string _testName = "test name";
    private readonly decimal _testPrice = 1.23m;

    private static readonly JsonSerializerOptions JsonOptions =
        new JsonSerializerOptions { PropertyNameCaseInsensitive = true };

    [TestMethod]
    public async Task ReturnsNotAuthorizedGivenNormalUserToken()
    {
        var jsonContent = GetValidNewItemJson();
        var token = ApiTokenHelper.GetNormalUserToken();
        var client = ProgramTest.NewClient;
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", token);

        // Route prefixed with /api/v1/ per API design rules.
        var response = await client.PostAsync("/api/v1/catalog-items", jsonContent);

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

        var response = await client.PostAsync("/api/v1/catalog-items", jsonContent);
        response.EnsureSuccessStatusCode();

        var stringResponse = await response.Content.ReadAsStringAsync();
        var model = JsonSerializer.Deserialize<CreateCatalogItemResponse>(stringResponse, JsonOptions);

        Assert.IsNotNull(model);
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
