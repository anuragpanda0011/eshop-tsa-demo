# Modernized eShopOnWeb — UAT branch

Produced by the Agentic AI Infrastructure & Application Modernization platform
(`app-modernize-prod`), run `12a67e80`, and running at
https://app-eshop-uat.azurewebsites.net

## What the modernization agent produced

Azure-native configuration: Key Vault through managed identity, Azure SQL for
production, Redis distributed cache, Service Bus domain events, Blob storage,
Communication Services email, structured JSON logging and health endpoints.

## Fixes applied on top, to make it build and run

The generated output did not compile as delivered. These were required:

1. Restored 130 files the agent dropped — including `App.razor`, `_Imports.razor`
   and the CatalogItemPage components (`Create/Delete/Details/Edit.razor`) that
   `List.razor.cs` still referenced.
2. Restored `Directory.Packages.props`; 78 of 105 `PackageReference` entries take
   their version from it.
3. Declared versions for 7 dependencies the agent introduced without any
   (`Azure.Messaging.ServiceBus`, `StackExchange.Redis`, `Azure.Storage.Blobs`,
   `Azure.Communication.Email`, others) — NuGet NU1010.
4. Re-added `Microsoft.EntityFrameworkCore.InMemory`, dropped while the code
   calling `UseInMemoryDatabase` was left in place.
5. Added missing `using System.Collections.Generic;` and `using System.Linq;`.
6. Updated the `AppIdentityDbContextSeed.SeedAsync` call site — the agent added an
   `IConfiguration` parameter without changing its own caller.
7. Added `LoggingServiceBusPublisher`: the agent declared `IServiceBusPublisher`
   and made `OrderService` and `BasketService` depend on it, but wrote no
   implementation and no DI registration, so container validation aborted startup.
8. Made `<TargetFramework>` explicit in each `.csproj` — Oryx reads it from the
   project file and cannot see it inherited from `Directory.Packages.props`.
9. Removed the stale `CachedCatalogLookupDataServiceDecorator .cs` (note the
   space in the file name). The agent rewrote the decorator under the correct
   file name but left the original in place, so `BlazorAdmin.Services` declared
   the type twice and the build failed with CS0101/CS0111.

10. Added a per-item **Remove** button to the basket. Upstream only lets you
    delete a line by typing `0` into the quantity box and pressing Update,
    which reads as a no-op; `OnPostRemove` zeroes just that line, drops the
    cached view and redirects.

11. Fixed identity seeding, which failed on every start. The agent moved the
    seed passwords to configuration (`Seeding:*`) but nothing supplied them, so
    `AppIdentityDbContextSeed` threw, the surrounding `try/catch` swallowed it as
    `DatabaseSeedError`, and **no user accounts were ever created** — while the
    catalog, seeded first, made the site look healthy. The passwords are now
    supplied as App Service settings.
12. The login page hardcoded a password while the seeder read one from
    configuration, so the two could silently disagree. The page no longer shows
    any password — it names the seeded account only — and the accounts were
    renamed to `buyer@eshoponweb.com` / `admin@eshoponweb.com`. The password
    comes from `Seeding:BuyerPassword` and is never rendered.

## Running it

`ASPNETCORE_ENVIRONMENT=Development` and `UseOnlyInMemoryDatabase=true` run it
without Azure SQL or Key Vault, which is how the App Service above is configured.
