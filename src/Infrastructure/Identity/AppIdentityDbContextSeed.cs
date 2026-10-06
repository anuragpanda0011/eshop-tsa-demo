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
    /// Seeds the identity database with default roles and users.
    ///
    /// Passwords are read from environment variables / Azure Key Vault secrets:
    ///   Seeding__BuyerPassword      — password for the storefront buyer account
    ///   Seeding__AdminUserPassword  — password for the admin user account
    ///
    /// These must NEVER be hardcoded in source.  The method will throw at startup
    /// if either secret is absent so the service fails fast with a clear message.
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

        // --- Read seed passwords from configuration (Key Vault / env-vars) -------
        var buyerPassword = configuration["Seeding:BuyerPassword"];
        if (string.IsNullOrWhiteSpace(buyerPassword))
        {
            throw new InvalidOperationException(
                "Seed password for the storefront buyer account is not configured. " +
                "Set the 'Seeding__BuyerPassword' environment variable or Key Vault secret.");
        }

        var adminUserPassword = configuration["Seeding:AdminUserPassword"];
        if (string.IsNullOrWhiteSpace(adminUserPassword))
        {
            throw new InvalidOperationException(
                "Seed password for the admin user is not configured. " +
                "Set the 'Seeding__AdminUserPassword' environment variable or Key Vault secret.");
        }

        // --- Roles ---------------------------------------------------------------
        const string adminRoleName = BlazorShared.Authorization.Constants.Roles.ADMINISTRATORS;

        if (await roleManager.FindByNameAsync(adminRoleName) == null)
        {
            var roleResult = await roleManager.CreateAsync(new IdentityRole(adminRoleName));
            if (!roleResult.Succeeded)
            {
                logger.LogWarning(
                    "Failed to create role '{Role}': {Errors}",
                    adminRoleName,
                    string.Join(", ", roleResult.Errors));
            }
        }

        // --- Storefront buyer account --------------------------------------------
        const string buyerUserName = "buyer@eshoponweb.com";
        if (await userManager.FindByNameAsync(buyerUserName) == null)
        {
            var defaultUser = new ApplicationUser
            {
                UserName = buyerUserName,
                Email = buyerUserName
            };

            var result = await userManager.CreateAsync(defaultUser, buyerPassword);
            if (!result.Succeeded)
            {
                logger.LogWarning(
                    "Failed to create buyer account '{User}': {Errors}",
                    buyerUserName,
                    string.Join(", ", result.Errors));
            }
            else
            {
                logger.LogInformation("Buyer account '{User}' created successfully.", buyerUserName);
            }
        }

        // --- Admin user ----------------------------------------------------------
        const string adminUserName = "admin@eshoponweb.com";
        if (await userManager.FindByNameAsync(adminUserName) == null)
        {
            var adminUser = new ApplicationUser
            {
                UserName = adminUserName,
                Email = adminUserName
            };

            var result = await userManager.CreateAsync(adminUser, adminUserPassword);
            if (!result.Succeeded)
            {
                logger.LogWarning(
                    "Failed to create admin user '{User}': {Errors}",
                    adminUserName,
                    string.Join(", ", result.Errors));
            }
            else
            {
                logger.LogInformation("Admin user '{User}' created successfully.", adminUserName);
            }
        }

        var existingAdmin = await userManager.FindByNameAsync(adminUserName);
        if (existingAdmin != null && !await userManager.IsInRoleAsync(existingAdmin, adminRoleName))
        {
            var addRoleResult = await userManager.AddToRoleAsync(existingAdmin, adminRoleName);
            if (!addRoleResult.Succeeded)
            {
                logger.LogWarning(
                    "Failed to add user '{User}' to role '{Role}': {Errors}",
                    adminUserName,
                    adminRoleName,
                    string.Join(", ", addRoleResult.Errors));
            }
            else
            {
                logger.LogInformation(
                    "Admin user '{User}' added to role '{Role}'.",
                    adminUserName,
                    adminRoleName);
            }
        }
    }
}
