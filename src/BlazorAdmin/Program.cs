using System;
using System.Net.Http;
using System.Threading.Tasks;
using BlazorAdmin;
using BlazorAdmin.Services;
using Blazored.LocalStorage;
using BlazorShared;
using BlazorShared.Models;
using Microsoft.AspNetCore.Components.Authorization;
using Microsoft.AspNetCore.Components.Web;
using Microsoft.AspNetCore.Components.WebAssembly.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

var builder = WebAssemblyHostBuilder.CreateDefault(args);
builder.RootComponents.Add<App>("#admin");
builder.RootComponents.Add<HeadOutlet>("head::after");

// ---------------------------------------------------------------------------
// Base URL configuration
// Configuration values are loaded from appsettings.json / appsettings.{env}.json
// at build time (Blazor WASM has no server-side env-var access at runtime, but
// the host app injects the correct appsettings file for the target environment).
// ---------------------------------------------------------------------------
var configSection = builder.Configuration.GetRequiredSection(BaseUrlConfiguration.CONFIG_NAME);
builder.Services.Configure<BaseUrlConfiguration>(configSection);

// ---------------------------------------------------------------------------
// HttpClient — base address points at the hosting origin; the API base is
// resolved from configuration inside each service.
// ---------------------------------------------------------------------------
builder.Services.AddScoped(sp =>
    new HttpClient { BaseAddress = new Uri(builder.HostEnvironment.BaseAddress) });

// ---------------------------------------------------------------------------
// Application services
// ---------------------------------------------------------------------------
builder.Services.AddScoped<ToastService>();
builder.Services.AddScoped<HttpService>();

builder.Services.AddBlazoredLocalStorage();

builder.Services.AddAuthorizationCore();
builder.Services.AddScoped<AuthenticationStateProvider, CustomAuthStateProvider>();
builder.Services.AddScoped(sp =>
    (CustomAuthStateProvider)sp.GetRequiredService<AuthenticationStateProvider>());

builder.Services.AddBlazorServices();

// ---------------------------------------------------------------------------
// Logging — structured JSON output is handled by the browser console sink;
// log levels are driven by configuration (appsettings.json).
// ---------------------------------------------------------------------------
builder.Logging.AddConfiguration(builder.Configuration.GetRequiredSection("Logging"));

// ---------------------------------------------------------------------------
// Clear stale local-storage cache entries on startup so that users always
// receive fresh data after a new deployment.
// ---------------------------------------------------------------------------
await ClearLocalStorageCache(builder.Services);

await builder.Build().RunAsync();

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
static async Task ClearLocalStorageCache(IServiceCollection services)
{
    var sp = services.BuildServiceProvider();
    var localStorageService = sp.GetRequiredService<ILocalStorageService>();

    await localStorageService.RemoveItemAsync(typeof(CatalogBrand).Name);
    await localStorageService.RemoveItemAsync(typeof(CatalogType).Name);
}
