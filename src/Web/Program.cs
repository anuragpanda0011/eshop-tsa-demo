using System.Net.Mime;
using System.Text.Json;
using Ardalis.ListStartupServices;
using Azure.Identity;
using Azure.Messaging.ServiceBus;
using BlazorAdmin;
using BlazorAdmin.Services;
using Blazored.LocalStorage;
using BlazorShared;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc.ApplicationModels;
using Microsoft.EntityFrameworkCore;
using Microsoft.eShopWeb;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.eShopWeb.Infrastructure.Data;
using Microsoft.eShopWeb.Infrastructure.Identity;
using Microsoft.eShopWeb.Web;
using Microsoft.eShopWeb.Web.Configuration;
using Microsoft.eShopWeb.Web.HealthChecks;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using StackExchange.Redis;

var builder = WebApplication.CreateBuilder(args);

// -------------------------------------------------------------------
// Structured JSON logging to stdout
// -------------------------------------------------------------------
builder.Logging.ClearProviders();
builder.Logging.AddConsole(options =>
{
    options.FormatterName = "json";
});
builder.Logging.AddConsoleFormatter<Microsoft.Extensions.Logging.Console.JsonConsoleFormatter,
    Microsoft.Extensions.Logging.Console.JsonConsoleFormatterOptions>();

// -------------------------------------------------------------------
// Configuration: Key Vault in production, env vars always
// -------------------------------------------------------------------
builder.Configuration.AddEnvironmentVariables();

var isDevelopment = builder.Environment.IsDevelopment() ||
                    builder.Environment.EnvironmentName == "Docker";

if (!isDevelopment)
{
    var kvEndpoint = builder.Configuration["AZURE_KEY_VAULT_ENDPOINT"]
        ?? throw new InvalidOperationException(
            "AZURE_KEY_VAULT_ENDPOINT env var is required in production.");

    var credential = new ChainedTokenCredential(
        new AzureDeveloperCliCredential(),
        new DefaultAzureCredential());

    builder.Configuration.AddAzureKeyVault(new Uri(kvEndpoint), credential);
}

// -------------------------------------------------------------------
// Database
// -------------------------------------------------------------------
if (isDevelopment)
{
    Microsoft.eShopWeb.Infrastructure.Dependencies.ConfigureServices(
        builder.Configuration, builder.Services);
}
else
{
    var catalogConnStr = builder.Configuration[
        builder.Configuration["AZURE_SQL_CATALOG_CONNECTION_STRING_KEY"] ?? ""]
        ?? throw new InvalidOperationException(
            "Catalog DB connection string is required.");

    var identityConnStr = builder.Configuration[
        builder.Configuration["AZURE_SQL_IDENTITY_CONNECTION_STRING_KEY"] ?? ""]
        ?? throw new InvalidOperationException(
            "Identity DB connection string is required.");

    builder.Services.AddDbContext<CatalogContext>(c =>
        c.UseSqlServer(catalogConnStr,
            sqlOptions => sqlOptions.EnableRetryOnFailure()));

    builder.Services.AddDbContext<AppIdentityDbContext>(options =>
        options.UseSqlServer(identityConnStr,
            sqlOptions => sqlOptions.EnableRetryOnFailure()));
}

// -------------------------------------------------------------------
// Redis (distributed cache + session)
// -------------------------------------------------------------------
var redisConnectionString = builder.Configuration["REDIS_CONNECTION_STRING"]
    ?? throw new InvalidOperationException(
        "REDIS_CONNECTION_STRING env var is required.");

// Enforce TLS for managed Redis in production
if (!isDevelopment &&
    !redisConnectionString.Contains("ssl=true", StringComparison.OrdinalIgnoreCase) &&
    !redisConnectionString.StartsWith("rediss://", StringComparison.OrdinalIgnoreCase))
{
    throw new InvalidOperationException(
        "Redis connection string must use TLS (ssl=true or rediss://) in production.");
}

builder.Services.AddSingleton<IConnectionMultiplexer>(
    ConnectionMultiplexer.Connect(redisConnectionString));

builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = redisConnectionString;
    options.InstanceName = "eShopWeb:";
});

builder.Services.AddSession(options =>
{
    options.Cookie.HttpOnly = true;
    options.Cookie.IsEssential = true;
    options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
    options.IdleTimeout = TimeSpan.FromMinutes(30);
});

// -------------------------------------------------------------------
// Azure Service Bus
// -------------------------------------------------------------------
var serviceBusConnectionString = builder.Configuration["ServiceBus:ConnectionString"]
    ?? throw new InvalidOperationException(
        "ServiceBus:ConnectionString env var is required.");

builder.Services.AddSingleton(
    new ServiceBusClient(serviceBusConnectionString,
        new ServiceBusClientOptions
        {
            TransportType = ServiceBusTransportType.AmqpTcp
        }));

// -------------------------------------------------------------------
// Cookie & Authentication
// -------------------------------------------------------------------
builder.Services.AddCookieSettings();

builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.Cookie.HttpOnly = true;
        options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
        options.Cookie.SameSite = SameSiteMode.Lax;
    });

builder.Services.AddIdentity<ApplicationUser, IdentityRole>()
    .AddDefaultUI()
    .AddEntityFrameworkStores<AppIdentityDbContext>()
    .AddDefaultTokenProviders();

// -------------------------------------------------------------------
// Application services
// -------------------------------------------------------------------
builder.Services.AddScoped<ITokenClaimsService, IdentityTokenClaimService>();
builder.Services.AddCoreServices(builder.Configuration);
builder.Services.AddWebServices(builder.Configuration);

// -------------------------------------------------------------------
// HTTP clients (used by health checks — avoids HttpClient socket exhaustion)
// -------------------------------------------------------------------
builder.Services.AddHttpClient("healthcheck")
    .ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler
    {
        ServerCertificateCustomValidationCallback =
            HttpClientHandler.DangerousAcceptAnyServerCertificateValidator
    });

// -------------------------------------------------------------------
// Caching (memory cache kept for Blazor; Redis is the distributed store)
// -------------------------------------------------------------------
builder.Services.AddMemoryCache();

// -------------------------------------------------------------------
// MVC / Razor Pages
// -------------------------------------------------------------------
builder.Services.AddRouting(options =>
{
    options.ConstraintMap["slugify"] = typeof(SlugifyParameterTransformer);
});

builder.Services.AddMvc(options =>
{
    options.Conventions.Add(
        new RouteTokenTransformerConvention(new SlugifyParameterTransformer()));
});

builder.Services.AddControllersWithViews();

builder.Services.AddRazorPages(options =>
{
    options.Conventions.AuthorizePage("/Basket/Checkout");
});

builder.Services.AddHttpContextAccessor();

// -------------------------------------------------------------------
// Health checks
// -------------------------------------------------------------------
builder.Services
    .AddHealthChecks()
    .AddCheck<ApiHealthCheck>("api_health_check",
        tags: new[] { "apiHealthCheck" })
    .AddCheck<HomePageHealthCheck>("home_page_health_check",
        tags: new[] { "homePageHealthCheck" })
    .AddRedis(redisConnectionString,
        name: "redis",
        tags: new[] { "redis" });

builder.Services.Configure<ServiceConfig>(config =>
{
    config.Services = new List<ServiceDescriptor>(builder.Services);
    config.Path = "/allservices";
});

// -------------------------------------------------------------------
// Blazor configuration
// -------------------------------------------------------------------
var configSection = builder.Configuration.GetRequiredSection(BaseUrlConfiguration.CONFIG_NAME);
builder.Services.Configure<BaseUrlConfiguration>(configSection);
var baseUrlConfig = configSection.Get<BaseUrlConfiguration>();

builder.Services.AddScoped<HttpClient>(_ => new HttpClient
{
    BaseAddress = new Uri(baseUrlConfig!.WebBase)
});

builder.Services.AddBlazoredLocalStorage();
builder.Services.AddServerSideBlazor();
builder.Services.AddScoped<ToastService>();
builder.Services.AddScoped<HttpService>();
builder.Services.AddBlazorServices();

builder.Services.AddDatabaseDeveloperPageExceptionFilter();

// -------------------------------------------------------------------
// Build
// -------------------------------------------------------------------
var app = builder.Build();

// -------------------------------------------------------------------
// SIGTERM: graceful shutdown
// -------------------------------------------------------------------
var lifetime = app.Services.GetRequiredService<IHostApplicationLifetime>();
lifetime.ApplicationStopping.Register(() =>
{
    app.Logger.LogInformation(
        "SIGTERM received — draining requests and closing pools...");
});

// -------------------------------------------------------------------
// Seed database
// -------------------------------------------------------------------
app.Logger.LogInformation("App created...");
app.Logger.LogInformation("Seeding Database...");

using (var scope = app.Services.CreateScope())
{
    var scopedProvider = scope.ServiceProvider;
    try
    {
        var catalogContext = scopedProvider.GetRequiredService<CatalogContext>();
        await CatalogContextSeed.SeedAsync(catalogContext, app.Logger);

        var userManager = scopedProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var roleManager = scopedProvider.GetRequiredService<RoleManager<IdentityRole>>();
        var identityContext = scopedProvider.GetRequiredService<AppIdentityDbContext>();
        await AppIdentityDbContextSeed.SeedAsync(identityContext, userManager, roleManager);
    }
    catch (Exception ex)
    {
        app.Logger.LogError(ex, "An error occurred seeding the DB.");
    }
}

// -------------------------------------------------------------------
// PathBase
// -------------------------------------------------------------------
var catalogBaseUrl = builder.Configuration.GetValue<string>("CatalogBaseUrl");
if (!string.IsNullOrEmpty(catalogBaseUrl))
{
    app.Use((context, next) =>
    {
        context.Request.PathBase = new PathString(catalogBaseUrl);
        return next();
    });
}

// -------------------------------------------------------------------
// Health check endpoint
// -------------------------------------------------------------------
app.UseHealthChecks("/health",
    new HealthCheckOptions
    {
        ResponseWriter = async (context, report) =>
        {
            var result = JsonSerializer.Serialize(new
            {
                status = report.Status.ToString(),
                errors = report.Entries.Select(e => new
                {
                    key = e.Key,
                    value = Enum.GetName(typeof(HealthStatus), e.Value.Status)
                })
            });
            context.Response.ContentType = MediaTypeNames.Application.Json;
            await context.Response.WriteAsync(result);
        }
    });

// -------------------------------------------------------------------
// Middleware pipeline
// -------------------------------------------------------------------
if (isDevelopment)
{
    app.Logger.LogInformation("Adding Development middleware...");
    app.UseDeveloperExceptionPage();
    app.UseShowAllServicesMiddleware();
    app.UseMigrationsEndPoint();
    app.UseWebAssemblyDebugging();
}
else
{
    app.Logger.LogInformation("Adding non-Development middleware...");
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseBlazorFrameworkFiles();
app.UseStaticFiles();
app.UseRouting();
app.UseSession();
app.UseCookiePolicy();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllerRoute(
    "default",
    "{controller:slugify=Home}/{action:slugify=Index}/{id?}");
app.MapRazorPages();
app.MapHealthChecks("home_page_health_check",
    new HealthCheckOptions
    {
        Predicate = check => check.Tags.Contains("homePageHealthCheck")
    });
app.MapHealthChecks("api_health_check",
    new HealthCheckOptions
    {
        Predicate = check => check.Tags.Contains("apiHealthCheck")
    });
app.MapFallbackToFile("index.html");

app.Logger.LogInformation("LAUNCHING");
app.Run();
