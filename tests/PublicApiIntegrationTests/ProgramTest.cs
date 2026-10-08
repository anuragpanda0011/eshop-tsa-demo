using System;
using System.Collections.Generic;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Net.Http;

namespace PublicApiIntegrationTests;

[TestClass]
public class ProgramTest
{
    private static WebApplicationFactory<Program> _application = CreateFactory();

    /// <summary>
    /// Creates a new HttpClient for each test to ensure isolation.
    /// The underlying WebApplicationFactory (and its in-memory server) is shared
    /// across the assembly for performance.
    /// </summary>
    public static HttpClient NewClient => _application.CreateClient();

    [AssemblyInitialize]
    public static void AssemblyInitialize(TestContext _)
    {
        _application = CreateFactory();
    }

    [AssemblyCleanup]
    public static void AssemblyCleanup()
    {
        _application.Dispose();
    }

    private static WebApplicationFactory<Program> CreateFactory()
    {
        return new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder =>
            {
                builder.ConfigureAppConfiguration((_, config) =>
                {
                    // Force in-memory database mode for all integration tests.
                    // Secrets are never hardcoded here; they come from env vars.
                    config.AddInMemoryCollection(new Dictionary<string, string?>
                    {
                        ["UseOnlyInMemoryDatabase"] = "true",
                        // JWT secret: read from env var, fall back to a test-only value.
                        ["JwtConfig:Secret"] =
                            Environment.GetEnvironmentVariable("JWT_SECRET_KEY")
                            ?? "test-secret-key-min-32-chars-long!!",
                        ["JwtConfig:AllowedAlgorithms:0"] = "HS256"
                    });
                });
            });
    }
}
