using Ardalis.Specification.EntityFrameworkCore;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;

namespace Microsoft.eShopWeb.Infrastructure.Data;

/// <summary>
/// Generic EF Core repository backed by <see cref="CatalogContext"/> (Azure SQL Database).
/// All reads go through Ardalis.Specification; writes use EF Core change tracking.
/// </summary>
public class EfRepository<T> : RepositoryBase<T>, IReadRepository<T>, IRepository<T>
    where T : class, IAggregateRoot
{
    public EfRepository(CatalogContext dbContext) : base(dbContext)
    {
    }
}
