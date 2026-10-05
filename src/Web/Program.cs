using System.Net.Mime;
using System.Text.Json;
using Ardalis.ListStartupServices;
using Azure.Identity;
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

// ---------------------------------------------------------------------------
// Structured JSON logging to stdout
// ---------------------------------------------------------------------------
builder.Logging.ClearProviders();
builder.Logging.AddJsonConsole(opts =>
{
    opts.IncludeScopes = true;
    opts.TimestampFormat = "o";
});

// ---------------------------------------------------------------------------
// Configuration: Key Vault in non-dev environments
// ---------------------------------------------------------------------------
var isDevelopment = builder.Environment.IsDevelopment()
                    || builder.Environment.EnvironmentName == "Docker";

if (!isDevelopment)
{
    var keyVaultEndpoint = builder.Configuration["AZURE_KEY_VAULT_ENDPOINT"]
        ?? throw new InvalidOperationException(
            "AZURE_KEY_VAULT_ENDPOINT environment variable is required in non-development environments.");

    var credential = new ChainedTokenCredential(
        new AzureDeveloperCliCredential(),
        new DefaultAzureCredential());

    builder.Configuration.AddAzureKeyVault(new Uri(keyVaultEndpoint), credential);
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------
if (isDevelopment)
{
    Microsoft.eShopWeb.Infrastructure.Dependencies.ConfigureServices(builder.Configuration, builder.Services);
}
else
{
    builder.Services.AddDbContext<CatalogContext>(c =>
    {
        var connKey = builder.Configuration["AZURE_SQL_CATALOG_CONNECTION_STRING_KEY"]
            ?? throw new InvalidOperationException("AZURE_SQL_CATALOG_CONNECTION_STRING_KEY is required.");
        var connectionString = builder.Configuration[connKey]
            ?? throw new InvalidOperationException($"Connection string key '{connKey}' not found in configuration.");
        c.UseSqlServer(connectionString, sqlOptions =>
        {
            sqlOptions.EnableRetryOnFailure(maxRetryCount: 5);
        });
    });

    builder.Services.AddDbContext<AppIdentityDbContext>(options =>
    {
        var connKey = builder.Configuration["AZURE_SQL_IDENTITY_CONNECTION_STRING_KEY"]
            ?? throw new InvalidOperationException("AZURE_SQL_IDENTITY_CONNECTION_STRING_KEY is required.");
        var connectionString = builder.Configuration[connKey]
            ?? throw new InvalidOperationException($"Connection string key '{connKey}' not found in configuration.");
        options.UseSqlServer(connectionString, sqlOptions =>
        {
            sqlOptions.EnableRetryOnFailure(maxRetryCount: 5);
        });
    });
}

// ---------------------------------------------------------------------------
// Redis – distributed cache and session basket
// ---------------------------------------------------------------------------
var redisConnectionString = builder.Configuration["REDIS_CONNECTION_STRING"];
if (!string.IsNullOrWhiteSpace(redisConnectionString))
{
    // In production enforce rediss:// (TLS)
    if (!isDevelopment && !redisConnectionString.StartsWith("rediss://", StringComparison.OrdinalIgnoreCase))
    {
        throw new InvalidOperationException(
            "REDIS_CONNECTION_STRING must use the rediss:// scheme (TLS) in non-development environments.");
    }

    builder.Services.AddStackExchangeRedisCache(options =>
    {
        options.Configuration = redisConnectionString;
        options.InstanceName = "eshop:web:";
    });

    builder.Services.AddSingleton<IConnectionMultiplexer>(
        ConnectionMultiplexer.Connect(redisConnectionString));
}
else
{
    builder.Services.AddDistributedMemoryCache();
}

// ---------------------------------------------------------------------------
// Cookie / Auth
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// Application services
// ---------------------------------------------------------------------------
builder.Services.AddScoped<ITokenClaimsService, IdentityTokenClaimService>();
builder.Configuration.AddEnvironmentVariables();
builder.Services.AddCoreServices(builder.Configuration);
builder.Services.AddWebServices(builder.Configuration);

builder.Services.AddMemoryCache();

builder.Services.AddRouting(options =>
{
    options.ConstraintMap["slugify"] = typeof(SlugifyParameterTransformer);
});

builder.Services.AddMvc(options =>
{
    options.Conventions.Add(new RouteTokenTransformerConvention(new SlugifyParameterTransformer()));
});

builder.Services.AddControllersWithViews();

builder.Services.AddRazorPages(options =>
{
    options.Conventions.AuthorizePage("/Basket/Checkout");
});

builder.Services.AddHttpContextAccessor();

builder.Services
    .AddHealthChecks()
    .AddCheck<ApiHealthCheck>("api_health_check", tags: new[] { "apiHealthCheck" })
    .AddCheck<HomePageHealthCheck>("home_page_health_check", tags: new[] { "homePageHealthCheck" });

builder.Services.Configure<ServiceConfig>(config =>
{
    config.Services = new List<ServiceDescriptor>(builder.Services);
    config.Path = "/allservices";
});

// ---------------------------------------------------------------------------
// Blazor configuration
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// Build
// ---------------------------------------------------------------------------
var app = builder.Build();

var logger = app.Logger;
logger.LogInformation("{\"event\":\"AppCreated\",\"environment\":\"{Environment\"}}", app.Environment.EnvironmentName);

// ---------------------------------------------------------------------------
// SIGTERM: graceful shutdown
// ---------------------------------------------------------------------------
var appLifetime = app.Services.GetRequiredService<IHostApplicationLifetime>();
appLifetime.ApplicationStopping.Register(() =>
{
    logger.LogInformation("{\"event\":\"ApplicationStopping\",\"message\":\"SIGTERM received, draining requests.\"}");
});

// ---------------------------------------------------------------------------
// Database seeding
// ---------------------------------------------------------------------------
logger.LogInformation("{\"event\":\"DatabaseSeeding\",\"message\":\"Seeding database...\"}");

using (var scope = app.Services.CreateScope())
{
    var scopedProvider = scope.ServiceProvider;
    try
    {
        var catalogContext = scopedProvider.GetRequiredService<CatalogContext>();
        await CatalogContextSeed.SeedAsync(catalogContext, logger);

        var userManager = scopedProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var roleManager = scopedProvider.GetRequiredService<RoleManager<IdentityRole>>();
        var identityContext = scopedProvider.GetRequiredService<AppIdentityDbContext>();
        await AppIdentityDbContextSeed.SeedAsync(identityContext, userManager, roleManager);
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "{\"event\":\"DatabaseSeedError\",\"message\":\"An error occurred seeding the DB.\"}");
    }
}

// ---------------------------------------------------------------------------
// Middleware
// ---------------------------------------------------------------------------
var catalogBaseUrl = builder.Configuration.GetValue<string>("CatalogBaseUrl");
if (!string.IsNullOrEmpty(catalogBaseUrl))
{
    app.Use((context, next) =>
    {
        context.Request.PathBase = new PathString(catalogBaseUrl);
        return next();
    });
}

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

if (isDevelopment)
{
    logger.LogInformation("{\"event\":\"MiddlewareSetup\",\"message\":\"Adding Development middleware.\"}");
    app.UseDeveloperExceptionPage();
    app.UseShowAllServicesMiddleware();
    app.UseMigrationsEndPoint();
    app.UseWebAssemblyDebugging();
}
else
{
    logger.LogInformation("{\"event\":\"MiddlewareSetup\",\"message\":\"Adding Production middleware.\"}");
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseBlazorFrameworkFiles();
app.UseStaticFiles();
app.UseRouting();

app.UseCookiePolicy();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllerRoute("default", "{controller:slugify=Home}/{action:slugify=Index}/{id?}");
app.MapRazorPages();
app.MapHealthChecks("home_page_health_check",
    new HealthCheckOptions { Predicate = check => check.Tags.Contains("homePageHealthCheck") });
app.MapHealthChecks("api_health_check",
    new HealthCheckOptions { Predicate = check => check.Tags.Contains("apiHealthCheck") });
app.MapFallbackToFile("index.html");

logger.LogInformation("{\"event\":\"Launching\",\"message\":\"LAUNCHING\"}");
app.Run();
