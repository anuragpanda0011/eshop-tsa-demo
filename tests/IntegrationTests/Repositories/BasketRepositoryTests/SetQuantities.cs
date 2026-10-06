using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.eShopWeb.ApplicationCore.Entities.BasketAggregate;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.eShopWeb.ApplicationCore.Services;
using Microsoft.eShopWeb.Infrastructure.Data;
using Microsoft.eShopWeb.UnitTests.Builders;
using Microsoft.Extensions.Logging;
using Xunit;
using Xunit.Abstractions;

namespace Microsoft.eShopWeb.IntegrationTests.Repositories.BasketRepositoryTests;

public class SetQuantities : IDisposable
{
    private readonly CatalogContext _catalogContext;
    private readonly EfRepository<Basket> _basketRepository;
    private readonly BasketBuilder BasketBuilder = new BasketBuilder();
    private readonly ITestOutputHelper _output;

    public SetQuantities(ITestOutputHelper output)
    {
        _output = output;

        // Use a unique database name per test instance to avoid cross-test contamination
        var dbName = $"TestCatalog_BasketSetQuantities_{Guid.NewGuid()}";
        var dbOptions = new DbContextOptionsBuilder<CatalogContext>()
            .UseInMemoryDatabase(databaseName: dbName)
            .Options;

        _catalogContext = new CatalogContext(dbOptions);
        _basketRepository = new EfRepository<Basket>(_catalogContext);

        EmitStructuredLog("SetQuantities test initialized", new { DatabaseName = dbName });
    }

    [Fact]
    public async Task RemoveEmptyQuantities()
    {
        var basket = BasketBuilder.WithOneBasketItem();
        var basketService = new BasketService(_basketRepository, null!);

        await _basketRepository.AddAsync(basket);
        await _catalogContext.SaveChangesAsync();

        EmitStructuredLog("RemoveEmptyQuantities: basket added", new
        {
            BasketId = BasketBuilder.BasketId,
            InitialItemCount = basket.Items.Count
        });

        await basketService.SetQuantities(
            BasketBuilder.BasketId,
            new Dictionary<string, int> { { BasketBuilder.BasketId.ToString(), 0 } });

        EmitStructuredLog("RemoveEmptyQuantities: quantities set to zero", new
        {
            BasketId = BasketBuilder.BasketId,
            FinalItemCount = basket.Items.Count
        });

        Assert.Equal(0, basket.Items.Count);
    }

    private void EmitStructuredLog(string message, object? context = null)
    {
        var logEntry = new
        {
            Timestamp = DateTimeOffset.UtcNow.ToString("O"),
            Level = "Information",
            Message = message,
            TestClass = nameof(SetQuantities),
            TraceId = System.Diagnostics.Activity.Current?.TraceId.ToString() ?? "N/A",
            Context = context
        };

        _output.WriteLine(JsonSerializer.Serialize(logEntry, new JsonSerializerOptions
        {
            WriteIndented = false
        }));
    }

    public void Dispose()
    {
        _catalogContext.Dispose();
    }
}
