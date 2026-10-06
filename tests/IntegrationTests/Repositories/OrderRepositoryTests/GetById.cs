using System;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.eShopWeb.ApplicationCore.Entities.OrderAggregate;
using Microsoft.eShopWeb.Infrastructure.Data;
using Microsoft.eShopWeb.UnitTests.Builders;
using Xunit;
using Xunit.Abstractions;

namespace Microsoft.eShopWeb.IntegrationTests.Repositories.OrderRepositoryTests;

public class GetById : IDisposable
{
    private readonly CatalogContext _catalogContext;
    private readonly EfRepository<Order> _orderRepository;
    private OrderBuilder OrderBuilder { get; } = new OrderBuilder();
    private readonly ITestOutputHelper _output;

    public GetById(ITestOutputHelper output)
    {
        _output = output;

        // Use a unique database name per test instance to avoid cross-test contamination
        var dbName = $"TestCatalog_OrderGetById_{Guid.NewGuid()}";
        var dbOptions = new DbContextOptionsBuilder<CatalogContext>()
            .UseInMemoryDatabase(databaseName: dbName)
            .Options;

        _catalogContext = new CatalogContext(dbOptions);
        _orderRepository = new EfRepository<Order>(_catalogContext);

        EmitStructuredLog("GetById test initialized", new { DatabaseName = dbName });
    }

    [Fact]
    public async Task GetsExistingOrder()
    {
        var existingOrder = OrderBuilder.WithDefaultValues();
        _catalogContext.Orders.Add(existingOrder);
        await _catalogContext.SaveChangesAsync();

        int orderId = existingOrder.Id;

        EmitStructuredLog("GetsExistingOrder: order persisted", new
        {
            OrderId = orderId,
            BuyerId = OrderBuilder.TestBuyerId
        });

        var orderFromRepo = await _orderRepository.GetByIdAsync(orderId);

        Assert.NotNull(orderFromRepo);
        Assert.Equal(OrderBuilder.TestBuyerId, orderFromRepo!.BuyerId);

        // Note: Using InMemoryDatabase, OrderItems is available in navigation property.
        // With a real SQL DB, use OrderWithItemsByIdSpec to eagerly load the full aggregate.
        var firstItem = orderFromRepo.OrderItems.FirstOrDefault();

        Assert.NotNull(firstItem);
        Assert.Equal(OrderBuilder.TestUnits, firstItem!.Units);

        EmitStructuredLog("GetsExistingOrder: assertions passed", new
        {
            OrderId = orderId,
            BuyerId = orderFromRepo.BuyerId,
            FirstItemUnits = firstItem.Units
        });
    }

    private void EmitStructuredLog(string message, object? context = null)
    {
        var logEntry = new
        {
            Timestamp = DateTimeOffset.UtcNow.ToString("O"),
            Level = "Information",
            Message = message,
            TestClass = nameof(GetById),
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
