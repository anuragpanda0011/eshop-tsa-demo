using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.Infrastructure.Identity;

public class AppIdentityDbContextSeed
{
    /// <summary>
    /// Seeds the identity database with default roles and seed users.
    ///
    /// Seed user passwords are read from configuration / environment variables
    /// (e.g. Key Vault secrets "SeedUserPassword" and "SeedAdminPassword").
    /// They are NEVER hardcoded here. If the secrets are absent the seed is
    /// skipped and a warning is logged so that the application still starts.
    /// </summary>
    public static async Task SeedAsync(
        AppIdentityDbContext identityDbContext,
        UserManager<ApplicationUser> userManager,
        RoleManager<IdentityRole> roleManager,
        IConfiguration configuration,
        ILogger logger)
    {
        if (identityDbContext.Database.IsSqlServer())
        {
            await identityDbContext.Database.MigrateAsync();
        }

        // ------------------------------------------------------------------
        // Roles
        // ------------------------------------------------------------------
        const string adminRole = BlazorShared.Authorization.Constants.Roles.ADMINISTRATORS;
        if (!await roleManager.RoleExistsAsync(adminRole))
        {
            var roleResult = await roleManager.CreateAsync(new IdentityRole(adminRole));
            if (!roleResult.Succeeded)
            {
                logger.LogWarning(
                    "Failed to create role '{Role}': {Errors}",
                    adminRole,
                    string.Join(", ", roleResult.Errors));
            }
        }

        // ------------------------------------------------------------------
        // Seed passwords — sourced from Key Vault / env vars, never hardcoded.
        // ------------------------------------------------------------------
        var demoPassword = configuration["SeedUserPassword"];
        var adminPassword = configuration["SeedAdminPassword"];

        if (string.IsNullOrWhiteSpace(demoPassword) || string.IsNullOrWhiteSpace(adminPassword))
        {
            logger.LogWarning(
                "Seed user passwords ('SeedUserPassword' / 'SeedAdminPassword') are not configured. " +
                "Skipping identity database seeding. Set these values in Azure Key Vault or environment variables.");
            return;
        }

        // ------------------------------------------------------------------
        // Demo user
        // ------------------------------------------------------------------
        const string demoUserName = "demouser@microsoft.com";
        if (await userManager.FindByNameAsync(demoUserName) == null)
        {
            var defaultUser = new ApplicationUser
            {
                UserName = demoUserName,
                Email = demoUserName,
                EmailConfirmed = true
            };
            var createResult = await userManager.CreateAsync(defaultUser, demoPassword);
            if (!createResult.Succeeded)
            {
                logger.LogWarning(
                    "Failed to create demo user '{User}': {Errors}",
                    demoUserName,
                    string.Join(", ", createResult.Errors));
            }
            else
            {
                logger.LogInformation("Seeded demo user '{User}'.", demoUserName);
            }
        }

        // ------------------------------------------------------------------
        // Admin user
        // ------------------------------------------------------------------
        const string adminUserName = "admin@microsoft.com";
        if (await userManager.FindByNameAsync(adminUserName) == null)
        {
            var adminUser = new ApplicationUser
            {
                UserName = adminUserName,
                Email = adminUserName,
                EmailConfirmed = true
            };
            var createResult = await userManager.CreateAsync(adminUser, adminPassword);
            if (!createResult.Succeeded)
            {
                logger.LogWarning(
                    "Failed to create admin user '{User}': {Errors}",
                    adminUserName,
                    string.Join(", ", createResult.Errors));
                return;
            }

            logger.LogInformation("Seeded admin user '{User}'.", adminUserName);
        }

        // Ensure admin role membership regardless of whether the user was just created.
        var existingAdmin = await userManager.FindByNameAsync(adminUserName);
        if (existingAdmin != null && !await userManager.IsInRoleAsync(existingAdmin, adminRole))
        {
            var addRoleResult = await userManager.AddToRoleAsync(existingAdmin, adminRole);
            if (!addRoleResult.Succeeded)
            {
                logger.LogWarning(
                    "Failed to add user '{User}' to role '{Role}': {Errors}",
                    adminUserName,
                    adminRole,
                    string.Join(", ", addRoleResult.Errors));
            }
        }
    }
}
