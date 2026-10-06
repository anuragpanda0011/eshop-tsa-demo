using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using BlazorShared.Models;

namespace BlazorShared.Interfaces;

public interface ICatalogItemService
{
    Task<CatalogItem> Create(CreateCatalogItemRequest catalogItem, CancellationToken cancellationToken = default);
    Task<CatalogItem> Edit(CatalogItem catalogItem, CancellationToken cancellationToken = default);
    Task<string> Delete(int id, CancellationToken cancellationToken = default);
    Task<CatalogItem> GetById(int id, CancellationToken cancellationToken = default);
    Task<List<CatalogItem>> ListPaged(int pageSize, CancellationToken cancellationToken = default);
    Task<List<CatalogItem>> List(CancellationToken cancellationToken = default);
}
