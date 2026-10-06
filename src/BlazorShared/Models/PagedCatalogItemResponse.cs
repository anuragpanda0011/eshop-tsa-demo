using System.Collections.Generic;

namespace BlazorShared.Models;

public class PagedCatalogItemResponse
{
    public List<CatalogItem> CatalogItems { get; set; } = new List<CatalogItem>();
    public int PageCount { get; set; } = 0;
    public int TotalCount { get; set; } = 0;
    public int PageIndex { get; set; } = 0;
    public int PageSize { get; set; } = 0;
}
