using BlazorAdmin.Services;
using BlazorShared.Interfaces;
using BlazorShared.Models;
using Microsoft.Extensions.DependencyInjection;

namespace BlazorAdmin;

public static class ServicesConfiguration
{
    public static IServiceCollection AddBlazorServices(this IServiceCollection services)
    {
        // CatalogBrand lookup — cached decorator over the concrete service
        services.AddScoped<ICatalogLookupDataService<CatalogBrand>,
            CachedCatalogLookupDataServiceDecorator<CatalogBrand, CatalogBrandResponse>>();
        services.AddScoped<CatalogLookupDataService<CatalogBrand, CatalogBrandResponse>>();

        // CatalogType lookup — cached decorator over the concrete service
        services.AddScoped<ICatalogLookupDataService<CatalogType>,
            CachedCatalogLookupDataServiceDecorator<CatalogType, CatalogTypeResponse>>();
        services.AddScoped<CatalogLookupDataService<CatalogType, CatalogTypeResponse>>();

        // CatalogItem — cached decorator over the concrete service
        services.AddScoped<ICatalogItemService, CachedCatalogItemServiceDecorator>();
        services.AddScoped<CatalogItemService>();

        return services;
    }
}
