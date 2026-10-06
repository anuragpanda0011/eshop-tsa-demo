using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Threading.Tasks;
using Azure.Messaging.ServiceBus;
using Microsoft.EntityFrameworkCore;
using Microsoft.eShopWeb.ApplicationCore.Entities;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.Infrastructure.Data;

public class CatalogContextSeed
{
    public static async Task SeedAsync(
        CatalogContext catalogContext,
        ILogger logger,
        ServiceBusClient? serviceBusClient = null,
        int retry = 0)
    {
        var retryForAvailability = retry;
        try
        {
            if (catalogContext.Database.IsSqlServer())
            {
                await catalogContext.Database.MigrateAsync();
            }

            bool seeded = false;

            if (!await catalogContext.CatalogBrands.AnyAsync())
            {
                await catalogContext.CatalogBrands.AddRangeAsync(
                    GetPreconfiguredCatalogBrands());

                await catalogContext.SaveChangesAsync();
                seeded = true;
            }

            if (!await catalogContext.CatalogTypes.AnyAsync())
            {
                await catalogContext.CatalogTypes.AddRangeAsync(
                    GetPreconfiguredCatalogTypes());

                await catalogContext.SaveChangesAsync();
                seeded = true;
            }

            if (!await catalogContext.CatalogItems.AnyAsync())
            {
                await catalogContext.CatalogItems.AddRangeAsync(
                    GetPreconfiguredItems());

                await catalogContext.SaveChangesAsync();
                seeded = true;
            }

            if (seeded && serviceBusClient != null)
            {
                await PublishSeedEventAsync(serviceBusClient, logger);
            }
        }
        catch (Exception ex)
        {
            if (retryForAvailability >= 10) throw;

            retryForAvailability++;

            logger.LogError(ex, "An error occurred seeding the catalog database. Retry attempt {Retry}.", retryForAvailability);
            await SeedAsync(catalogContext, logger, serviceBusClient, retryForAvailability);
            throw;
        }
    }

    private static async Task PublishSeedEventAsync(ServiceBusClient client, ILogger logger)
    {
        try
        {
            var queueOrTopic = Environment.GetEnvironmentVariable("SERVICEBUS_CATALOG_TOPIC") ?? "catalog-events";
            var sender = client.CreateSender(queueOrTopic);

            var payload = JsonSerializer.Serialize(new
            {
                EventType = "CatalogSeeded",
                Timestamp = DateTimeOffset.UtcNow,
                Source = "CatalogContextSeed"
            });

            var message = new ServiceBusMessage(payload)
            {
                ContentType = "application/json",
                Subject = "CatalogSeeded"
            };

            await sender.SendMessageAsync(message);

            logger.LogInformation(
                "{{\"event\":\"CatalogSeeded\",\"timestamp\":\"{Timestamp}\"}}",
                DateTimeOffset.UtcNow);
        }
        catch (Exception ex)
        {
            // Best-effort publish: log but do not throw
            logger.LogWarning(ex, "Failed to publish CatalogSeeded event to Service Bus. Continuing.");
        }
    }

    static IEnumerable<CatalogBrand> GetPreconfiguredCatalogBrands()
    {
        return new List<CatalogBrand>
        {
            new("Azure"),
            new(".NET"),
            new("Visual Studio"),
            new("SQL Server"),
            new("Other")
        };
    }

    static IEnumerable<CatalogType> GetPreconfiguredCatalogTypes()
    {
        return new List<CatalogType>
        {
            new("Mug"),
            new("T-Shirt"),
            new("Sheet"),
            new("USB Memory Stick")
        };
    }

    static IEnumerable<CatalogItem> GetPreconfiguredItems()
    {
        return new List<CatalogItem>
        {
            new(2, 2, ".NET Bot Black Sweatshirt",    ".NET Bot Black Sweatshirt",    19.5M,  "http://catalogbaseurltobereplaced/images/products/1.png"),
            new(1, 2, ".NET Black & White Mug",       ".NET Black & White Mug",       8.50M,  "http://catalogbaseurltobereplaced/images/products/2.png"),
            new(2, 5, "Prism White T-Shirt",          "Prism White T-Shirt",          12M,    "http://catalogbaseurltobereplaced/images/products/3.png"),
            new(2, 2, ".NET Foundation Sweatshirt",   ".NET Foundation Sweatshirt",   12M,    "http://catalogbaseurltobereplaced/images/products/4.png"),
            new(3, 5, "Roslyn Red Sheet",             "Roslyn Red Sheet",             8.5M,   "http://catalogbaseurltobereplaced/images/products/5.png"),
            new(2, 2, ".NET Blue Sweatshirt",         ".NET Blue Sweatshirt",         12M,    "http://catalogbaseurltobereplaced/images/products/6.png"),
            new(2, 5, "Roslyn Red T-Shirt",           "Roslyn Red T-Shirt",           12M,    "http://catalogbaseurltobereplaced/images/products/7.png"),
            new(2, 5, "Kudu Purple Sweatshirt",       "Kudu Purple Sweatshirt",       8.5M,   "http://catalogbaseurltobereplaced/images/products/8.png"),
            new(1, 5, "Cup<T> White Mug",             "Cup<T> White Mug",             12M,    "http://catalogbaseurltobereplaced/images/products/9.png"),
            new(3, 2, ".NET Foundation Sheet",        ".NET Foundation Sheet",        12M,    "http://catalogbaseurltobereplaced/images/products/10.png"),
            new(3, 2, "Cup<T> Sheet",                 "Cup<T> Sheet",                 8.5M,   "http://catalogbaseurltobereplaced/images/products/11.png"),
            new(2, 5, "Prism White TShirt",           "Prism White TShirt",           12M,    "http://catalogbaseurltobereplaced/images/products/12.png")
        };
    }
}
