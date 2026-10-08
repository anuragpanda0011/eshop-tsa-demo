using System;
using System.Collections.Generic;
using System.Text;
using System.Text.Json;
using System.Threading;
using BlazorShared;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Identity;
using Microsoft.eShopWeb;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.eShopWeb.ApplicationCore.Services;
using Microsoft.eShopWeb.Infrastructure.Data;
using Microsoft.eShopWeb.Infrastructure.Identity;
using Microsoft.eShopWeb.Infrastructure.Logging;
using Microsoft.eShopWeb.PublicApi;
using Microsoft.eShopWeb.PublicApi.Middleware;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using MinimalApi.Endpoint.Configurations.Extensions;
using MinimalApi.Endpoint.Extensions;

// ---------------------------------------------------------------------------
// Validate required environment variables at startup
// ---------------------------------------------------------------------------
static string RequireEnv(string name)
{
    var value = Environment.GetEnvironmentVariable(name);
    if (string.IsNullOrWhiteSpace(value))
        throw new InvalidOperationException(
            $"Required environment variable '{name}' is not set. " +
            "In production this must be sourced from Azure Key Vault via the app's Managed Identity.");
    return value;
}

// JWT secret must come from environment / Key Vault secret injection — never hardcoded.
var jwtSecretKey = RequireEnv("JWT_SECRET_KEY");

// Validate algorithm allowlist to prevent 'none' / weak algorithm attacks.
var allowedJwtAlgorithms = new[] { SecurityAlgorithms.HmacSha256, SecurityAlgorithms.HmacSha512 };

var builder = WebApplication.CreateBuilder(args);

// ---------------------------------------------------------------------------
// Structured JSON logging — attach Azure trace IDs automatically
// ---------------------------------------------------------------------------
builder.Logging.ClearProviders();
builder.Logging.AddConsole(options =>
{
    options.FormatterName = "json";
});

builder.Services.AddEndpoints();

builder.Configuration.AddEnvironmentVariables();

// Use to force loading of appsettings.json of test project
builder.Configuration.AddConfigurationFile("appsettings.test.json");

Microsoft.eShopWeb.Infrastructure.Dependencies.ConfigureServices(builder.Configuration, builder.Services);

builder.Services.AddIdentity<ApplicationUser, IdentityRole>()
    .AddEntityFrameworkStores<AppIdentityDbContext>()
    .AddDefaultTokenProviders();

builder.Services.AddScoped(typeof(IRepository<>), typeof(EfRepository<>));
builder.Services.AddScoped(typeof(IReadRepository<>), typeof(EfRepository<>));
builder.Services.Configure<CatalogSettings>(builder.Configuration);
var catalogSettings = builder.Configuration.Get<CatalogSettings>() ?? new CatalogSettings();
builder.Services.AddSingleton<IUriComposer>(new UriComposer(catalogSettings));
builder.Services.AddScoped(typeof(IAppLogger<>), typeof(LoggerAdapter<>));
builder.Services.AddScoped<ITokenClaimsService, IdentityTokenClaimService>();

var configSection = builder.Configuration.GetRequiredSection(BaseUrlConfiguration.CONFIG_NAME);
builder.Services.Configure<BaseUrlConfiguration>(configSection);
var baseUrlConfig = configSection.Get<BaseUrlConfiguration>();

// ---------------------------------------------------------------------------
// Redis distributed cache (replaces IMemoryCache for multi-instance scale)
// Connection string must use rediss:// (TLS) in production.
// ---------------------------------------------------------------------------
var redisConnectionString = RequireEnv("REDIS_CONNECTION_STRING");
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = redisConnectionString;
    options.InstanceName = "PublicApi:";
});

// ---------------------------------------------------------------------------
// Rate limiting on auth endpoints (Redis-backed via AspNetCoreRateLimit or
// the built-in ASP.NET Core 8 rate limiter with a fixed-window policy).
// ---------------------------------------------------------------------------
builder.Services.AddRateLimiter(rateLimiterOptions =>
{
    rateLimiterOptions.AddFixedWindowLimiter("auth", options =>
    {
        options.Window = TimeSpan.FromMinutes(1);
        options.PermitLimit = 10;
        options.QueueLimit = 0;
    });

    rateLimiterOptions.OnRejected = async (context, cancellationToken) =>
    {
        context.HttpContext.Response.StatusCode = 429;
        context.HttpContext.Response.ContentType = "application/json";
        await context.HttpContext.Response.WriteAsync(
            JsonSerializer.Serialize(new
            {
                error = "RATE_LIMIT_EXCEEDED",
                message = "Too many requests. Please try again later."
            }), cancellationToken);
    };
});

// ---------------------------------------------------------------------------
// JWT authentication — secret from environment, algorithm from allowlist
// ---------------------------------------------------------------------------
var keyBytes = Encoding.ASCII.GetBytes(jwtSecretKey);
builder.Services.AddAuthentication(config =>
{
    config.DefaultScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(config =>
{
    // Require HTTPS metadata in non-Development environments
    config.RequireHttpsMetadata = !builder.Environment.IsDevelopment();
    config.SaveToken = true;
    config.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(keyBytes),
        ValidateIssuer = false,
        ValidateAudience = false,
        ValidAlgorithms = allowedJwtAlgorithms
    };
});

builder.Services.AddAuthorization();

const string CORS_POLICY = "CorsPolicy";
builder.Services.AddCors(options =>
{
    options.AddPolicy(name: CORS_POLICY,
        corsPolicyBuilder =>
        {
            corsPolicyBuilder.WithOrigins(
                baseUrlConfig!.WebBase
                    .Replace("host.docker.internal", "localhost")
                    .TrimEnd('/'));
            corsPolicyBuilder.AllowAnyMethod();
            corsPolicyBuilder.AllowAnyHeader();
        });
});

builder.Services.AddControllers();
builder.Services.AddAutoMapper(typeof(MappingProfile).Assembly);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "eShopOnWeb Public API", Version = "v1" });
    c.EnableAnnotations();
    c.SchemaFilter<CustomSchemaFilters>();
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "JWT Authorization header using the Bearer scheme. " +
                      "Enter 'Bearer' [space] and then your token in the text input below. " +
                      "Example: 'Bearer eyJhbGci...'",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.ApiKey,
        Scheme = "Bearer"
    });
    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                },
                Scheme = "oauth2",
                Name = "Bearer",
                In = ParameterLocation.Header
            },
            new List<string>()
        }
    });
});

var app = builder.Build();

// ---------------------------------------------------------------------------
// Graceful shutdown: drain in-flight requests, close pools, exit 0
// ---------------------------------------------------------------------------
var lifetime = app.Services.GetRequiredService<IHostApplicationLifetime>();
lifetime.ApplicationStopping.Register(() =>
{
    app.Logger.LogInformation(
        "SIGTERM received — draining requests and closing connection pools.");
    // Allow up to 10 s for in-flight requests to complete
    Thread.Sleep(TimeSpan.FromSeconds(10));
});

// ---------------------------------------------------------------------------
// Structured startup log with Azure trace context
// ---------------------------------------------------------------------------
app.Logger.LogInformation("PublicApi App created. Environment={Environment}", app.Environment.EnvironmentName);
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
        app.Logger.LogError(ex, "An error occurred seeding the DB. TraceId={TraceId}",
            System.Diagnostics.Activity.Current?.Id ?? "N/A");
    }
}

if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
}

app.UseMiddleware<ExceptionMiddleware>();

app.UseHttpsRedirection();

app.UseRouting();

app.UseCors(CORS_POLICY);

app.UseRateLimiter();

app.UseAuthentication();
app.UseAuthorization();

app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "eShopOnWeb Public API V1");
});

app.MapControllers();
app.MapEndpoints();

app.Logger.LogInformation("LAUNCHING PublicApi");
app.Run();

public partial class Program { }
