using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.eShopWeb.PublicApi.CatalogItemEndpoints;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace PublicApiIntegrationTests.CatalogItemEndpoints;

[TestClass]
public class CatalogItemListPagedEndpointTest
{
    private static readonly JsonSerializerOptions JsonOptions =
        new JsonSerializerOptions { PropertyNameCaseInsensitive = true };

    [TestMethod]
    public async Task ReturnsFirst10CatalogItems()
    {
        var client = ProgramTest.NewClient;
        // Route prefixed with /api/v1/ per API design rules.
        var response = await client.GetAsync("/api/v1/catalog-items?pageSize=10");
        response.EnsureSuccessStatusCode();

        var stringResponse = await response.Content.ReadAsStringAsync();
        var model = JsonSerializer.Deserialize<ListPagedCatalogItemResponse>(stringResponse, JsonOptions);

        Assert.IsNotNull(model);
        Assert.AreEqual(10, model!.CatalogItems.Count());
    }

    [TestMethod]
    public async Task ReturnsCorrectCatalogItemsGivenPageIndex1()
    {
        var pageSize = 10;
        var pageIndex = 1;

        var client = ProgramTest.NewClient;

        // Get total count from the first page
        var response = await client.GetAsync("/api/v1/catalog-items");
        response.EnsureSuccessStatusCode();
        var stringResponse = await response.Content.ReadAsStringAsync();
        var model = JsonSerializer.Deserialize<ListPagedCatalogItemResponse>(stringResponse, JsonOptions);
        var totalItem = model!.CatalogItems.Count();

        // Get page 1
        var response2 = await client.GetAsync(
            $"/api/v1/catalog-items?pageSize={pageSize}&pageIndex={pageIndex}");
        response2.EnsureSuccessStatusCode();
        var stringResponse2 = await response2.Content.ReadAsStringAsync();
        var model2 = JsonSerializer.Deserialize<ListPagedCatalogItemResponse>(stringResponse2, JsonOptions);

        var totalExpected = totalItem - (pageSize * pageIndex);
        Assert.AreEqual(totalExpected, model2!.CatalogItems.Count());
    }

    [DataTestMethod]
    [DataRow("catalog-items")]
    [DataRow("catalog-brands")]
    [DataRow("catalog-types")]
    [DataRow("catalog-items/1")]
    public async Task SuccessFullMultipleParallelCall(string endpointName)
    {
        var client = ProgramTest.NewClient;
        var tasks = new List<Task<HttpResponseMessage>>();

        for (int i = 0; i < 100; i++)
        {
            var task = client.GetAsync($"/api/v1/{endpointName}");
            tasks.Add(task);
        }

        await Task.WhenAll(tasks);

        var totalKO = tasks.Count(t => t.Result.StatusCode != HttpStatusCode.OK);
        Assert.AreEqual(0, totalKO);
    }
}
