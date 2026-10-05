using System.Net;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.eShopWeb.PublicApi.CatalogItemEndpoints;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace PublicApiIntegrationTests.CatalogItemEndpoints;

[TestClass]
public class CatalogItemGetByIdEndpointTest
{
    private static readonly JsonSerializerOptions JsonOptions =
        new JsonSerializerOptions { PropertyNameCaseInsensitive = true };

    [TestMethod]
    public async Task ReturnsItemGivenValidId()
    {
        // Route prefixed with /api/v1/ per API design rules.
        var response = await ProgramTest.NewClient.GetAsync("/api/v1/catalog-items/5");
        response.EnsureSuccessStatusCode();

        var stringResponse = await response.Content.ReadAsStringAsync();
        var model = JsonSerializer.Deserialize<GetByIdCatalogItemResponse>(stringResponse, JsonOptions);

        Assert.IsNotNull(model);
        Assert.AreEqual(5, model!.CatalogItem.Id);
        Assert.AreEqual("Roslyn Red Sheet", model.CatalogItem.Name);
    }

    [TestMethod]
    public async Task ReturnsNotFoundGivenInvalidId()
    {
        var response = await ProgramTest.NewClient.GetAsync("/api/v1/catalog-items/0");

        Assert.AreEqual(HttpStatusCode.NotFound, response.StatusCode);
    }
}
