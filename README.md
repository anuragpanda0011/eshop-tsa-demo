# Microsoft eShopOnWeb ASP.NET Core — Production-Grade Azure Cloud-Native

> **This fork has been modernized for production deployment on Microsoft Azure.**
> For the original community reference application, see https://github.com/dotnet/eShop.
> For the original eShopOnWeb, see https://github.com/NimblePros/eShopOnWeb.

Sample ASP.NET Core 8.0 reference application demonstrating a **cloud-native, Azure-hosted** architecture using Container Apps, Azure SQL, Redis, Service Bus, Azure Communication Services, and Key Vault — following the [Reliable Web App](https://learn.microsoft.com/azure/architecture/web-apps/guides/reliable-web-app/overview) pattern.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                  Azure Front Door (WAF, CDN)                 │
└───────────────────────┬─────────────────────────────────────┘
                        │
          ┌─────────────┴──────────────┐
          │                            │
┌─────────▼──────────┐    ┌────────────▼────────────┐
│  Web Frontend       │    │  BlazorAdmin             │
│  Azure Container   │    │  Azure Static Web Apps   │
│  Apps              │    │  (edge delivery)         │
└─────────┬──────────┘    └────────────┬─────────────┘
          │                            │
          └─────────────┬──────────────┘
                        │
          ┌─────────────▼──────────────┐
          │  PublicApi                 │
          │  Azure Container Apps      │
          │  (internal ingress)        │
          └──┬──────────┬──────────────┘
             │          │
   ┌──────────▼──┐  ┌───▼──────────────────┐
   │ Azure SQL   │  │ Azure Cache for Redis │
   │ Database    │  │ (Standard C1)         │
   │ catalogdb   │  └───────────────────────┘
   │ identitydb  │
   └─────────────┘

Supporting Services:
  - Azure Key Vault (RBAC, private endpoint)
  - Azure Service Bus (structured domain events)
  - Azure Communication Services (transactional email)
  - Azure Container Registry (Premium, geo-replication)
  - Azure Monitor + Application Insights (workspace-based)
  - Azure Virtual Network + Private Endpoints + NSGs
```

---

## Key Security & Compliance Changes

| Area | Before | After |
|---|---|---|
| Secrets | Hardcoded in `AuthorizationConstants.cs` and `appsettings.json` | Azure Key Vault via Managed Identity; zero secrets in code |
| JWT signing key | Literal string in source | Key Vault secret, validated against algorithm allowlist at startup |
| Password hashing | ASP.NET Identity default (can be weak) | Argon2 / bcrypt via updated Identity configuration |
| SQL connections | Connection strings with username/password in config | Azure SQL with Entra (AAD) Managed Identity auth; `sslmode=require` |
| Redis connections | Plain `redis://` | `rediss://` (TLS) enforced at startup; keys hashed before use |
| Blob/file storage | Local filesystem | Azure Blob Storage (server-side encryption, MIME validation, 50 MB limit) |
| Email | SMTP | Azure Communication Services Email SDK |
| Auth endpoints | Unthrottled | Redis-backed rate limiting on `/api/v1/auth/**` |
| Route prefix | `/` | All API routes prefixed `/api/v1/` |
| Idempotency | None | `X-Idempotency-Key` header on all money/inventory POST endpoints (24 h Redis cache) |
| Network | Public SQL + public App Service | All PaaS on private endpoints inside VNet |
| WAF | None | Azure Front Door WAF (OWASP 3.2 ruleset) |

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| .NET SDK | 8.0+ | https://dot.net |
| Azure Developer CLI (`azd`) | latest | https://aka.ms/azure-dev/install |
| Azure CLI | latest | https://aka.ms/azure-cli |
| Docker Desktop | latest | https://docker.com |
| Git | any | https://git-scm.com |

---

## Quickstart — Deploy to Azure with AZD

### 1. Install Azure Developer CLI

**Windows (PowerShell):**
```powershell
powershell -ex AllSigned -c "Invoke-RestMethod 'https://aka.ms/install-azd.ps1' | Invoke-Expression"
```

**Linux / macOS:**
```bash
curl -fsSL https://aka.ms/install-azd.sh | bash
```

You can also use package managers (`winget`, `choco`, `brew`). See https://aka.ms/azure-dev/install.

### 2. Authenticate

```bash
azd auth login
az login
```

### 3. Initialize the environment

```bash
azd init -t dotnet-architecture/eShopOnWeb
```

### 4. Provision and deploy

```bash
azd up
```

When prompted:
- Enter an **environment name** (e.g., `eshoponweb-prod`). The resource group will be named `rg-{env-name}`.
- Select your **subscription**.
- Select a **region** (recommend `eastus2` or `westeurope` for paired-region availability).

`azd up` will:
1. Provision all Azure infrastructure via Bicep (VNet, Container Apps environment, Azure SQL, Redis, Key Vault, Service Bus, Communication Services, Container Registry, Front Door, App Insights).
2. Build container images and push to Azure Container Registry.
3. Deploy Web, PublicApi, and BlazorAdmin containers.
4. Seed the databases on first run (catalog + identity).
5. Output the Front Door endpoint URL.

> **Security note:** All secrets (SQL passwords, JWT signing key, Redis connection string) are stored exclusively in Azure Key Vault. The application retrieves them at startup via Managed Identity — no secrets appear in `appsettings.json`, environment variable files, or source code.

### 5. Access the application

After `azd up` completes, the CLI outputs:
```
Outputs:
  webEndpoint  = https://<env-name>.azurefd.net
  apiEndpoint  = https://<env-name>-api.internal.azurecontainerapps.io
```

Browse to `https://<env-name>.azurefd.net` for the storefront.
Browse to `https://<env-name>.azurefd.net/admin` for the Blazor admin panel.

Default seeded credentials (change immediately in production):
- **Buyer:** `demouser@microsoft.com` — stored hashed in Azure SQL Identity DB
- **Admin:** see Key Vault secret `DefaultAdminPassword` — rotated on first login

---

## Running Locally

### Option A — Full local stack with Docker Compose

```bash
git clone https://github.com/dotnet-architecture/eShopOnWeb
cd eShopOnWeb
cp .env.example .env          # fill in local overrides — never commit .env
docker-compose up --build
```

Services started:
| Service | Local URL |
|---|---|
| Web (MVC storefront) | https://localhost:5001 |
| PublicApi | https://localhost:5200 |
| SQL Server (local dev only) | localhost:1433 |
| Redis | localhost:6379 |
| Azurite (blob emulator) | http://localhost:10000 |
| MailDev (email preview) | http://localhost:1080 |

> **Note:** Docker Compose uses local emulators and a dev-only SQL Server container. The production path always uses Azure-managed services. Secrets in `.env` are for local development only — never commit this file.

### Option B — Run without Docker (VS Code / Visual Studio)

#### 1. Set up local secrets

```bash
cd src/Web
dotnet user-secrets set "ConnectionStrings:CatalogConnection" "Server=localhost;Database=Microsoft.eShopOnWeb.CatalogDb;User Id=sa;Password=<YourStrong!Passw0rd>;TrustServerCertificate=True"
dotnet user-secrets set "ConnectionStrings:IdentityConnection" "Server=localhost;Database=Microsoft.eShopOnWeb.Identity;User Id=sa;Password=<YourStrong!Passw0rd>;TrustServerCertificate=True"
dotnet user-secrets set "Redis:ConnectionString" "localhost:6379"
dotnet user-secrets set "Auth:JwtSigningKey" "<minimum-32-char-random-string>"

cd ../PublicApi
dotnet user-secrets set "ConnectionStrings:CatalogConnection" "<same as above>"
dotnet user-secrets set "Auth:JwtSigningKey" "<same key as above>"
dotnet user-secrets set "Redis:ConnectionString" "localhost:6379"
```

> All secrets are read from environment variables / user secrets at startup. The application **will not start** if required secrets are missing — it fails fast with a descriptive error.

#### 2. Run EF Core migrations

```bash
dotnet tool update --global dotnet-ef

# From repo root:
dotnet ef database update -c catalogcontext \
  -p src/Infrastructure/Infrastructure.csproj \
  -s src/Web/Web.csproj

dotnet ef database update -c appidentitydbcontext \
  -p src/Infrastructure/Infrastructure.csproj \
  -s src/Web/Web.csproj
```

#### 3. Start the applications

**Terminal 1 (PublicApi):**
```bash
cd src/PublicApi
dotnet run
```

**Terminal 2 (Web):**
```bash
cd src/Web
dotnet run --launch-profile Web
```

Browse to `https://localhost:5001` (storefront) and `https://localhost:5001/admin` (Blazor admin).

#### 4. Optional — in-memory database (no SQL Server required)

Add to `src/Web/appsettings.Development.json`:
```json
{
  "UseOnlyInMemoryDatabase": true
}
```

---

## Environment Variables Reference

All configuration is driven by environment variables (or Azure Key Vault in production). The following variables **must** be set:

| Variable | Description | Production source |
|---|---|---|
| `ConnectionStrings__CatalogConnection` | Azure SQL catalog DB connection string | Key Vault secret |
| `ConnectionStrings__IdentityConnection` | Azure SQL identity DB connection string | Key Vault secret |
| `Redis__ConnectionString` | `rediss://<host>:6380` (TLS required in prod) | Key Vault secret |
| `Auth__JwtSigningKey` | Minimum 32-character random string | Key Vault secret |
| `Auth__JwtIssuer` | Token issuer URI | App configuration |
| `Auth__JwtAudience` | Token audience URI | App configuration |
| `Storage__ConnectionString` | Azure Blob Storage connection string | Key Vault secret |
| `Storage__ContainerName` | Blob container name for catalog images | App configuration |
| `Email__ConnectionString` | Azure Communication Services connection string | Key Vault secret |
| `Email__SenderAddress` | Verified sender address | App configuration |
| `ServiceBus__ConnectionString` | Azure Service Bus namespace connection string | Key Vault secret |
| `ServiceBus__TopicName` | Service Bus topic for domain events | App configuration |
| `ApplicationInsights__ConnectionString` | App Insights connection string (not ikey) | App configuration |
| `ASPNETCORE_ENVIRONMENT` | `Production` / `Development` | Container environment |
| `KeyVault__Uri` | Key Vault URI (Managed Identity used — no secret needed) | App configuration |

> In production on Azure Container Apps, most of these are injected automatically from Key Vault references configured during `azd up`. You do **not** manually set them.

---

## API Reference

All REST endpoints are prefixed `/api/v1/`. See the live Swagger UI at:
- Local: `https://localhost:5200/swagger`
- Azure: `https://<env-name>.azurefd.net/api/docs`

### Authentication

```http
POST /api/v1/auth/authenticate
Content-Type: application/json
X-Idempotency-Key: <uuid>

{
  "username": "demouser@microsoft.com",
  "password": "your-password"
}
```

Returns a JWT Bearer token. Rate-limited to **10 requests / minute per IP** (Redis-backed). Excess requests receive `429 Too Many Requests`.

### Idempotency

All POST endpoints that modify orders, basket, or inventory accept an optional `X-Idempotency-Key` header (UUID v4 recommended). Responses are cached in Redis for 24 hours — retrying with the same key returns the cached response without re-executing the operation.

```http
POST /api/v1/orders
X-Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000
Authorization: Bearer <token>
```

### Error Responses

All errors follow the standard envelope:

```json
{
  "error": "RESOURCE_NOT_FOUND",
  "message": "Catalog item with id 42 was not found.",
  "traceId": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
}
```

---

## Observability

- **Structured JSON logs** emitted to stdout on every request; Azure trace ID attached to every log line.
- **Application Insights** workspace-based — distributed tracing, dependency tracking, live metrics.
- **Azure Monitor Alerts** configured for: 5xx spike, P95 latency > 2 s, failed auth rate > 5 %, Redis eviction rate.
- **Log Analytics Workspace** — 30-day hot retention, 90-day cold.

View logs:
```bash
az containerapp logs show \
  --name eshoponweb-web \
  --resource-group rg-<env-name> \
  --follow
```

---

## CI/CD Pipeline

GitHub Actions (`.github/workflows/`) implements:

```
Push to main
  └── build-and-test.yml
        ├── dotnet build + test (all projects)
        ├── OIDC login → Azure (no stored credentials)
        ├── docker build → push to Azure Container Registry
        └── azd deploy → Azure Container Apps (blue/green)
```

No secrets are stored in GitHub repository settings. Authentication uses **OIDC federated credentials** (`azure/login` with `client-id`, `tenant-id`, `subscription-id` — all non-secret values).

---

## EF Core Migrations (Adding New Migrations)

```bash
# Catalog context
dotnet ef migrations add <MigrationName> \
  --context catalogcontext \
  -p src/Infrastructure/Infrastructure.csproj \
  -s src/Web/Web.csproj \
  -o Data/Migrations

# Identity context
dotnet ef migrations add <MigrationName> \
  --context appidentitydbcontext \
  -p src/Infrastructure/Infrastructure.csproj \
  -s src/Web/Web.csproj \
  -o Identity/Migrations
```

Migrations are applied automatically on startup in development. In production, `azd up` runs a migration job as a Container Apps job before deploying the new application version.

---

## Dev Container

This project includes a `.devcontainer` configuration for GitHub Codespaces and VS Code Dev Containers. The dev container includes all required tooling (.NET 8 SDK, Azure CLI, azd, Docker-in-Docker, EF tools) — no local installation needed.

Open in GitHub Codespaces:

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/dotnet-architecture/eShopOnWeb)

See [`.devcontainer/devcontainerreadme.md`](.devcontainer/devcontainerreadme.md) for details.

---

## Project Structure

```
eShopOnWeb/
├── src/
│   ├── ApplicationCore/        # Domain model — Basket, Order, Buyer, Catalog aggregates
│   ├── Infrastructure/         # EF Core, Identity, Repository implementations,
│   │                           # Azure Storage, Service Bus, Communication Services
│   ├── Web/                    # ASP.NET Core MVC storefront (Container App)
│   ├── PublicApi/              # REST API — minimal API, JWT auth, Swagger
│   └── BlazorAdmin/            # Blazor WASM admin SPA (Azure Static Web Apps)
├── tests/
│   ├── UnitTests/
│   ├── IntegrationTests/
│   └── FunctionalTests/
├── infra/                      # Bicep IaC — all Azure resources
│   ├── main.bicep
│   ├── modules/
│   │   ├── containerApps.bicep
│   │   ├── sql.bicep
│   │   ├── redis.bicep
│   │   ├── keyVault.bicep
│   │   ├── serviceBus.bicep
│   │   ├── communicationServices.bicep
│   │   ├── frontDoor.bicep
│   │   └── monitoring.bicep
│   └── abbreviations.json
├── .github/
│   └── workflows/
│       ├── build-and-test.yml
│       └── deploy.yml
├── azure.yaml                  # AZD template manifest
├── docker-compose.yml          # Local development only
├── .env.example                # Template for local .env — never commit .env
└── README.md
```

---

## eBook

This application accompanies the free eBook:
[Architecting Modern Web Applications with ASP.NET Core and Azure](https://aka.ms/webappebook) (ASP.NET Core 8.0 edition).

Also available at: https://docs.microsoft.com/dotnet/architecture/modern-web-apps-azure/

[<img src="https://dotnet.microsoft.com/blob-assets/images/e-books/aspnet.png" height="300" />](https://dotnet.microsoft.com/learn/web/aspnet-architecture)

---

## Related Samples

| Sample | Focus |
|---|---|
| [eShopOnContainers](https://github.com/dotnet/eShopOnContainers) | Microservices / containers architecture |
| [eShop (.NET Aspire)](https://github.com/dotnet/eShop) | .NET Aspire cloud-native reference |
| [Reliable Web App Pattern](https://aka.ms/eap/rwa/dotnet) | Production reliability patterns for Azure |

---

## Community Extensions

- [eShopOnWeb VB.NET](https://github.com/VBAndCs/eShopOnWeb_VB.NET) — by Mohammad Hamdy Ghanem
- [FShopOnWeb](https://github.com/NitroDevs/FShopOnWeb) — F# implementation by Sean G. Wright and Kyle McMaster

> Community extensions are not maintained by Microsoft and do not reflect the production-Azure architecture described in this README.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). All PRs must pass:
- `dotnet test` (unit + integration)
- Security scan (`dotnet list package --vulnerable`)
- No secrets in diff (gitleaks pre-commit hook)
