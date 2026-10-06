using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.eShopWeb.ApplicationCore.Entities.OrderAggregate;
using Microsoft.eShopWeb.ApplicationCore.Specifications;
using Microsoft.eShopWeb.Infrastructure.Data;
using Microsoft.eShopWeb.UnitTests.Builders;
using Xunit;
using Xunit.Abstractions;

namespace Microsoft.eShopWeb.IntegrationTests.Repositories.OrderRepositoryTests;

public class GetByIdWithItemsAsync : IDisposable
{
    private readonly CatalogContext _catalogContext;
    private readonly EfRepository<Order> _orderRepository;
    private OrderBuilder OrderBuilder { get; } = new OrderBuilder();
    private readonly ITestOutputHelper _output;

    public GetByIdWithItemsAsync(ITestOutputHelper output)
    {
        _output = output;

        // Use a unique database name per test instance to avoid cross-test contamination
        var dbName = $"TestCatalog_OrderGetByIdWithItems_{Guid.NewGuid()}";
        var dbOptions = new DbContextOptionsBuilder<CatalogContext>()
            .UseInMemoryDatabase(databaseName: dbName)
            .Options;

        _catalogContext = new CatalogContext(dbOptions);
        _orderRepository = new EfRepository<Order>(_catalogContext);

        EmitStructuredLog("GetByIdWithItemsAsync test initialized", new { DatabaseName = dbName });
    }

    [Fact]
    public async Task GetOrderAndItemsByOrderIdWhenMultipleOrdersPresent()
    {
        // Arrange
        var itemOneUnitPrice = 5.50m;
        var itemOneUnits = 2;
        var itemTwoUnitPrice = 7.50m;
        var itemTwoUnits = 5;

        var firstOrder = OrderBuilder.WithDefaultValues();
        _catalogContext.Orders.Add(firstOrder);

        var secondOrderItems = new List<OrderItem>
        {
            new OrderItem(OrderBuilder.TestCatalogItemOrdered, itemOneUnitPrice, itemOneUnits),
            new OrderItem(OrderBuilder.TestCatalogItemOrdered, itemTwoUnitPrice, itemTwoUnits)
        };
        var secondOrder = OrderBuilder.WithItems(secondOrderItems);
        _catalogContext.Orders.Add(secondOrder);

        await _catalogContext.SaveChangesAsync();

        int firstOrderId = firstOrder.Id;
        int secondOrderId = secondOrder.Id;

        EmitStructuredLog("GetOrderAndItemsByOrderIdWhenMultipleOrdersPresent: orders persisted", new
        {
            FirstOrderId = firstOrderId,
            SecondOrderId = secondOrderId,
            SecondOrderItemCount = secondOrder.OrderItems.Count
        });

        // Act
        var spec = new OrderWithItemsByIdSpec(secondOrderId);
        var orderFromRepo = await _orderRepository.FirstOrDefaultAsync(spec);

        // Assert
        Assert.NotNull(orderFromRepo);
        Assert.Equal(secondOrderId, orderFromRepo!.Id);
        Assert.Equal(secondOrder.OrderItems.Count, orderFromRepo.OrderItems.Count);

        Assert.Equal(1, orderFromRepo.OrderItems.Count(x => x.UnitPrice == itemOneUnitPrice));
        Assert.Equal(1, orderFromRepo.OrderItems.Count(x => x.UnitPrice == itemTwoUnitPrice));

        var itemOne = orderFromRepo.OrderItems.SingleOrDefault(x => x.UnitPrice == itemOneUnitPrice);
        var itemTwo = orderFromRepo.OrderItems.SingleOrDefault(x => x.UnitPrice == itemTwoUnitPrice);

        Assert.NotNull(itemOne);
        Assert.NotNull(itemTwo);
        Assert.Equal(itemOneUnits, itemOne!.Units);
        Assert.Equal(itemTwoUnits, itemTwo!.Units);

        EmitStructuredLog("GetOrderAndItemsByOrderIdWhenMultipleOrdersPresent: assertions passed", new
        {
            SecondOrderId = secondOrderId,
            RetrievedItemCount = orderFromRepo.OrderItems.Count,
            ItemOneUnits = itemOne.Units,
            ItemTwoUnits = itemTwo.Units
        });
    }

    private void EmitStructuredLog(string message, object? context = null)
    {
        var logEntry = new
        {
            Timestamp = DateTimeOffset.UtcNow.ToString("O"),
            Level = "Information",
            Message = message,
            TestClass = nameof(GetByIdWithItemsAsync),
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
