using Microsoft.eShopWeb;
using Microsoft.eShopWeb.PublicApi.CatalogItemEndpoints;
using Microsoft.eShopWeb.Web.ViewModels;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Net;
using System.Threading.Tasks;

namespace PublicApiIntegrationTests.CatalogItemEndpoints;

[TestClass]
public class CatalogItemListPagedEndpoint
{
    [TestMethod]
    public async Task ReturnsFirst10CatalogItems()
    {
        var client = ProgramTest.NewClient;
        // Route updated to /api/v1/ prefix.
        var response = await client.GetAsync("/api/v1/catalog-items?pageSize=10");
        response.EnsureSuccessStatusCode();

        var stringResponse = await response.Content.ReadAsStringAsync();
        var model = stringResponse.FromJson<CatalogIndexViewModel>();

        Assert.IsNotNull(model, "Response body could not be deserialized.");
        Assert.AreEqual(10, model!.CatalogItems.Count());
    }

    [TestMethod]
    public async Task ReturnsCorrectCatalogItemsGivenPageIndex1()
    {
        var pageSize = 10;
        var pageIndex = 1;

        var client = ProgramTest.NewClient;

        // Fetch all items first (no pagination).
        var response = await client.GetAsync("/api/v1/catalog-items");
        response.EnsureSuccessStatusCode();
        var stringResponse = await response.Content.ReadAsStringAsync();
        var model = stringResponse.FromJson<ListPagedCatalogItemResponse>();
        Assert.IsNotNull(model, "First response body could not be deserialized.");
        var totalItem = model!.CatalogItems.Count();

        // Fetch second page.
        var response2 = await client.GetAsync(
            $"/api/v1/catalog-items?pageSize={pageSize}&pageIndex={pageIndex}");
        response2.EnsureSuccessStatusCode();
        var stringResponse2 = await response2.Content.ReadAsStringAsync();
        var model2 = stringResponse2.FromJson<ListPagedCatalogItemResponse>();
        Assert.IsNotNull(model2, "Second response body could not be deserialized.");

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
            tasks.Add(client.GetAsync($"/api/v1/{endpointName}"));
        }

        await Task.WhenAll(tasks);

        var totalKO = tasks.Count(t => t.Result.StatusCode != HttpStatusCode.OK);
        Assert.AreEqual(0, totalKO);
    }
}
