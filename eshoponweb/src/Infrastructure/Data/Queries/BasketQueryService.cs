using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.Infrastructure.Data.Queries;

public class BasketQueryService : IBasketQueryService
{
    private readonly CatalogContext _dbContext;
    private readonly ILogger<BasketQueryService> _logger;

    public BasketQueryService(CatalogContext dbContext, ILogger<BasketQueryService> logger)
    {
        _dbContext = dbContext;
        _logger = logger;
    }

    /// <summary>
    /// This method performs the sum on the database rather than in memory.
    /// </summary>
    /// <param name="username"></param>
    /// <returns></returns>
    public async Task<int> CountTotalBasketItems(string username)
    {
        _logger.LogInformation(
            "{Method} called for user {Username}",
            nameof(CountTotalBasketItems),
            username);

        var totalItems = await _dbContext.Baskets
            .Where(basket => basket.BuyerId == username)
            .SelectMany(item => item.Items)
            .SumAsync(sum => sum.Quantity);

        _logger.LogInformation(
            "{Method} completed for user {Username}. TotalItems={TotalItems}",
            nameof(CountTotalBasketItems),
            username,
            totalItems);

        return totalItems;
    }
}
