using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System;
using System.Net.Http;

namespace PublicApiIntegrationTests;

[TestClass]
public class ProgramTest
{
    private static WebApplicationFactory<Program> _application = new();

    /// <summary>
    /// Returns a new <see cref="HttpClient"/> per call so tests remain isolated.
    /// The factory itself is shared across the assembly for performance.
    /// </summary>
    public static HttpClient NewClient =>
        _application.CreateClient(new WebApplicationFactoryClientOptions
        {
            // Prevent the test client from following redirects automatically
            // so status-code assertions are exact.
            AllowAutoRedirect = false
        });

    [AssemblyInitialize]
    public static void AssemblyInitialize(TestContext _)
    {
        // Guard: ensure the JWT secret env-var is set before any test runs.
        var jwtSecret = Environment.GetEnvironmentVariable("ESHOPONWEB_JWT_SECRET");
        if (string.IsNullOrWhiteSpace(jwtSecret) || jwtSecret.Length < 32)
        {
            throw new InvalidOperationException(
                "Environment variable ESHOPONWEB_JWT_SECRET must be set to a " +
                "string of at least 32 characters before running integration tests. " +
                "In CI, populate this from Azure Key Vault or GitHub Actions secrets.");
        }

        // Guard: ensure the default password env-var is set before any test runs.
        var defaultPassword = Environment.GetEnvironmentVariable("ESHOPONWEB_DEFAULT_PASSWORD");
        if (string.IsNullOrWhiteSpace(defaultPassword))
        {
            throw new InvalidOperationException(
                "Environment variable ESHOPONWEB_DEFAULT_PASSWORD must be set " +
                "before running integration tests. " +
                "In CI, populate this from Azure Key Vault or GitHub Actions secrets.");
        }

        _application = new WebApplicationFactory<Program>();
    }

    [AssemblyCleanup]
    public static void AssemblyCleanup()
    {
        // Dispose the factory, which triggers graceful shutdown of the hosted
        // test server (drains in-flight requests, closes DB pools, etc.).
        _application?.Dispose();
    }
}
