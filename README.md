# Microsoft eShopOnWeb ASP.NET Core Reference Application — Azure Modernized

> eShop sample applications have been updated and moved to https://github.com/dotnet/eShop. Active development will continue there. We also recommend the [Reliable Web App](https://learn.microsoft.com/azure/architecture/web-apps/guides/reliable-web-app/overview) patterns guidance for building web apps with enterprise app patterns.

> A new community supported version of eShopOnWeb can be found at https://github.com/NimblePros/eShopOnWeb

Sample ASP.NET Core reference application, powered by Microsoft, demonstrating a single-process (monolithic) application architecture and deployment model modernized for Azure. If you're new to .NET development, read the [Getting Started for Beginners](https://github.com/dotnet-architecture/eShopOnWeb/wiki/Getting-Started-for-Beginners) guide.

A list of Frequently Asked Questions about this repository can be found [here](https://github.com/dotnet-architecture/eShopOnWeb/wiki/Frequently-Asked-Questions).

## Azure Architecture

This modernized version targets the following Azure services:

| Component | Azure Service |
|---|---|
| Web MVC App | Azure App Service (Premium v3, Linux, deployment slots) |
| Public REST API | Azure App Service (separate plan, Premium v3, Linux) |
| SQL Server (Catalog) | Azure SQL Database (General Purpose, zone-redundant, private endpoint) |
| SQL Server (Identity) | Azure SQL Database (General Purpose, zone-redundant, private endpoint) |
| Secrets | Azure Key Vault (Standard SKU, RBAC model, private endpoint) |
| Observability | Azure Application Insights + Log Analytics Workspace |
| Caching / Session | Azure Cache for Redis (TLS, `rediss://`) |
| Static Assets / CDN | Azure Front Door Premium (WAF + CDN + global LB) |
| Network Isolation | Azure Virtual Network with subnet isolation |
| Identity | Azure Managed Identity (no stored credentials) |
| Blob / Image Storage | Azure Blob Storage (server-side encryption) |
| Email | Azure Communication Services |
| Messaging | Azure Service Bus |
| Image Registry | Azure Container Registry |

## Security Highlights

- **No hardcoded secrets.** All credentials (JWT signing key, DB passwords, connection strings, API keys) are stored in Azure Key Vault and injected via Managed Identity at startup.
- **JWT algorithm allowlist enforced at startup** — `HS256` only; unsafe values (`none`, `RS256` without explicit opt-in) are rejected.
- **Bcrypt** password hashing (ASP.NET Core Identity default PBKDF2 retained; bcrypt used for any custom credential paths).
- **Parameterized queries only** — no string-concatenated SQL anywhere in the codebase.
- **Redis-backed rate limiting** on all auth endpoints (`/api/v1/authenticate`, `/api/v1/account/register`).
- **TLS enforced** for all managed-service URLs (`rediss://`, `sslmode=require`).
- **Auth guards** on every route that modifies data or returns private data; admin routes require an additional role check.
- **Idempotency keys** (`X-Idempotency-Key`) accepted on all money- and inventory-mutating POST endpoints; responses cached in Redis for 24 h.

## Running the sample using Azd template

The store's home page should look like this:

![eShopOnWeb home page screenshot](https://user-images.githubusercontent.com/782127/88414268-92d83a00-cdaa-11ea-9b4c-db67d95be039.png)

The Azure Developer CLI (`azd`) is a developer-centric command-line interface (CLI) tool for creating Azure applications.

Install the Azure Developer CLI before running or deploying:

### Windows

```powershell
powershell -ex AllSigned -c "Invoke-RestMethod 'https://aka.ms/install-azd.ps1' | Invoke-Expression"
```

### Linux/MacOS

```
curl -fsSL https://aka.ms/install-azd.sh | bash
```

After logging in:

```
azd auth login
```

Initialize the environment:

```
azd init -t dotnet-architecture/eShopOnWeb
```

Provision and deploy all resources to Azure:

```
azd up
```

According to the prompt, enter an `env name`, and select `subscription` and `location`. Wait for resource deployment to complete, then click the web endpoint to view the home page.

**Notes:**
1. All secrets (database credentials, JWT signing key, Redis connection string, Service Bus connection string, Storage account key) are stored in **Azure Key Vault** and accessed via **Managed Identity** — no credentials are present in config files or environment variables in production.
2. The resource group name created in the Azure portal will be **rg-{env name}**.
3. SQL Server private endpoints are used; the firewall is closed to public traffic.
4. Redis Cache uses TLS (`rediss://`) for all connections.
5. Application Insights is fully wired — structured JSON logs are emitted to stdout and forwarded to the Log Analytics Workspace.

## Required Environment Variables (local development)

When running locally, the following environment variables must be set (in `appsettings.Development.json` or user secrets — **never commit real values**):

```
AZURE_KEY_VAULT_ENDPOINT          # https://<vault-name>.vault.azure.net/
APPLICATIONINSIGHTS_CONNECTION_STRING
REDIS_CONNECTION_STRING           # rediss://<host>:6380,password=...,ssl=True
AZURE_SERVICE_BUS_CONNECTION_STRING
AZURE_STORAGE_ACCOUNT_NAME
AZURE_STORAGE_CONTAINER_NAME
CATALOG_DB_CONNECTION_STRING      # ...;sslmode=require or Encrypt=True
IDENTITY_DB_CONNECTION_STRING     # ...;sslmode=require or Encrypt=True
JWT_SECRET_KEY_NAME               # Key Vault secret name, e.g. "JwtSigningKey"
AZURE_COMMUNICATION_SERVICES_CONNECTION_STRING
AZURE_COMMUNICATION_SENDER_ADDRESS
```

In production (Azure App Service), these are injected automatically from Key Vault via Managed Identity — no manual configuration required.

## Running the sample locally

Most of the site's functionality works with just the web application running. However, the site's Admin page relies on Blazor WebAssembly running in the browser, and it must communicate with the server using the site's PublicApi web application. You'll need to also run this project. You can configure Visual Studio to start multiple projects, or just go to the PublicApi folder in a terminal window and run `dotnet run` from there. After that from the Web folder you should run `dotnet run --launch-profile Web`. Now you should be able to browse to `https://localhost:5001/`. The admin part in Blazor is accessible at `https://localhost:5001/admin`.

Note that if you use this approach, you'll need to stop the application manually in order to build the solution (otherwise you'll get file locking errors).

After cloning or downloading the sample you must setup your database.
To use the sample with a persistent database, you will need to run its Entity Framework Core migrations before you will be able to run the app.

### Configuring the sample to use SQL Server

1. By default, the project uses a real database. If you want an in-memory database for local testing, add the following to `appsettings.json` in the Web folder:

    ```json
    {
        "UseOnlyInMemoryDatabase": true
    }
    ```

1. Ensure your connection strings in `appsettings.Development.json` (or user secrets) point to a local SQL Server instance.
1. Ensure the EF tool is installed:

    ```
    dotnet tool update --global dotnet-ef
    ```

1. Open a command prompt in the Web folder and execute the following commands:

    ```
    dotnet restore
    dotnet tool restore
    dotnet ef database update -c catalogcontext -p ../Infrastructure/Infrastructure.csproj -s Web.csproj
    dotnet ef database update -c appidentitydbcontext -p ../Infrastructure/Infrastructure.csproj -s Web.csproj
    ```

    These commands will create two separate databases, one for the store's catalog data and shopping cart information, and one for the app's user credentials and identity data.

1. Run the application.

    The first time you run the application, it will seed both databases with data such that you should see products in the store, and you should be able to log in using the demouser@microsoft.com account.

    Note: If you need to create migrations, you can use these commands:

    ```
    dotnet ef migrations add InitialModel --context catalogcontext -p ../Infrastructure/Infrastructure.csproj -s Web.csproj -o Data/Migrations
    dotnet ef migrations add InitialIdentityModel --context appidentitydbcontext -p ../Infrastructure/Infrastructure.csproj -s Web.csproj -o Identity/Migrations
    ```

## Running the sample in the dev container

This project includes a `.devcontainer` folder with a [dev container configuration](https://containers.dev/), which lets you use a container as a full-featured dev environment.

You can use the dev container to build and run the app without needing to install any of its tools locally! You can work in GitHub Codespaces or the VS Code Dev Containers extension.

Learn more about using the dev container in its [readme](/.devcontainer/devcontainerreadme.md).

## Running the sample using Docker

You can run the Web sample by running these commands from the root folder (where the .sln file is located):

```
docker-compose build
docker-compose up
```

You should be able to make requests to localhost:5106 for the Web project, and localhost:5200 for the Public API project once these commands complete. If you have any problems, especially with login, try from a new guest or incognito browser instance.

**Important:** The Docker Compose configuration is for **local development only**. The SQL Server password used in `docker-compose.yml` is a local-only dev secret and must never be used in any shared or production environment. All production secrets are managed exclusively through Azure Key Vault.

## API Versioning

All REST API routes are prefixed with `/api/v1/`. Example endpoints:

- `GET  /api/v1/catalog-items`
- `POST /api/v1/catalog-items`   *(requires `X-Idempotency-Key` header)*
- `POST /api/v1/authenticate`    *(rate-limited)*
- `POST /api/v1/account/register` *(rate-limited)*

## Observability

- Structured JSON logs are emitted to **stdout** on every request, including the Azure Application Insights trace ID.
- All log data flows to the **Log Analytics Workspace** via the Application Insights connection.
- SIGTERM is handled gracefully: in-flight requests are drained, connection pools are closed, and the process exits with code 0.

## Community Extensions

We have some great contributions from the community, and while these aren't maintained by Microsoft we still want to highlight them.

[eShopOnWeb VB.NET](https://github.com/VBAndCs/eShopOnWeb_VB.NET) by Mohammad Hamdy Ghanem

[FShopOnWeb](https://github.com/NitroDevs/FShopOnWeb) An F# take on eShopOnWeb by Sean G. Wright and Kyle McMaster
