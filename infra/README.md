# eShopOnWeb — Production Azure Infrastructure (Terraform)

This repository contains production-grade Terraform code that provisions the
complete Azure infrastructure for the **eShopOnWeb** reference e-commerce
application. It converts the existing Azure Developer CLI (azd) / Bicep
deployment into a fully modular, secure, and observable Terraform project.

---

## Architecture Overview

```
Internet
   │
   ▼
Azure DNS (Public Zone) ──► Azure Front Door Premium
                                   │  WAF (OWASP CRS 2.1 + Bot Manager)
                                   │  CDN caching rules
                                   │  Custom domain + managed TLS
                                   │
          ┌────────────────────────┴────────────────────────┐
          │                                                  │
          ▼                                                  ▼
  Web Origin Group                                  API Origin Group
  (app-eshop-web-prod)                              (app-eshop-api-prod)
          │                                                  │
          └──────────────┬───────────────────────────────────┘
                         │ Azure VNet Integration (WEBSITE_VNET_ROUTE_ALL=1)
                         ▼
          ┌──────────────────────────────┐
          │  vnet-eshop-prod 10.0.0.0/16 │
          │                              │
          │  snet-web   10.0.1.0/24      │──► NAT Gateway (static IP)
          │  snet-api   10.0.2.0/24      │──► NAT Gateway (static IP)
          │  snet-redis 10.0.3.0/24      │◄── Azure Cache for Redis PE
          │  snet-sql   10.0.4.0/24      │◄── Azure SQL × 2 PEs
          │  snet-kv    10.0.5.0/24      │◄── Key Vault PE
          │  snet-build 10.0.6.0/24      │◄── ACR PE
          │  snet-mgmt  10.0.7.0/24      │◄── Azure Bastion
          └──────────────────────────────┘
```

---

## Module Structure

```
.
├── main.tf                    # Root: wires all modules
├── variables.tf               # Root variables
├── outputs.tf                 # Root outputs
├── providers.tf               # azurerm provider config
├── versions.tf                # Version constraints + backend
├── terraform.tfvars.example   # Example variable values
├── README.md
└── modules/
    ├── network/               # VNet, subnets, NSGs, NAT GW, Bastion, Private DNS
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── compute/               # App Service Plans, App Services, slots, autoscale, storage
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── database/              # Azure SQL × 2, Redis, private endpoints
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── security/              # Key Vault, ACR, RBAC, secrets, private endpoints
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── monitoring/            # Log Analytics, App Insights, alerts, web tests
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── ci_cd/                 # Azure Front Door Premium, WAF, CDN rules, DNS
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

---

## Prerequisites

| Tool | Minimum Version |
|------|----------------|
| Terraform | 1.7.0 |
| Azure CLI | 2.57.0 |
| azurerm provider | 3.110.x |

You also need:
- An Azure subscription with **Contributor** + **User Access Administrator** rights
  (or **Owner**) on the target subscription.
- An existing Azure DNS Zone if you want custom domain support.
- An Entra ID group/user object ID for SQL Entra Admin.

---

## Terraform State Backend

State is stored in Azure Blob Storage. Create it once before `terraform init`.

> **Security note**: The backend configuration is kept in a separate
> `backend.hcl` file that is **not** committed to source control.
> Copy `backend.hcl.example` to `backend.hcl` and fill in your values.

```bash
az group create -n rg-eshop-tfstate -l eastus2
az storage account create \
  -n steshoptfstateprod \
  -g rg-eshop-tfstate \
  -l eastus2 \
  --sku Standard_GRS \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --allow-shared-key-access false

az storage container create \
  -n tfstate \
  --account-name steshoptfstateprod

# Enable versioning and soft-delete on the state container
az storage account blob-service-properties update \
  --account-name steshoptfstateprod \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 30
```

Then initialise with the backend config file:
```bash
terraform init -backend-config=backend.hcl
```

---

## Quick Start

```bash
# 1. Clone and enter the repo
git clone <repo-url>
cd eshop-terraform

# 2. Create your tfvars file
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — fill in subscription_id, tenant_id, passwords, etc.

# 3. Copy and fill backend config
cp backend.hcl.example backend.hcl
# Edit backend.hcl with your state storage account details

# 4. Login to Azure
az login
az account set --subscription "<your-subscription-id>"

# 5. Initialise Terraform (generates .terraform.lock.hcl)
terraform init -backend-config=backend.hcl

# 6. Commit the lock file
git add .terraform.lock.hcl
git commit -m "chore: commit provider lock file"

# 7. Validate
terraform validate

# 8. Plan
terraform plan -out=tfplan

# 9. Apply
terraform apply tfplan
```

---

## Key Design Decisions

### Security
- **All SQL and Redis endpoints are private** — public network access is disabled.
- **Entra-only SQL authentication** (`azuread_authentication_only = true`) —
  password-based SQL logins are disabled. No SQL admin password is stored in
  Terraform state.
- **Key Vault uses RBAC** (not legacy Access Policies). Managed Identities are
  granted `Key Vault Secrets User` at the vault scope.
- **JWT secret** is generated by Terraform (`random_password`), stored in Key Vault,
  and injected via Managed Identity at runtime — never hardcoded.
- **FTPS is disabled** on all App Services; HTTPS-only enforced.
- **WAF in Prevention mode** with OWASP CRS 2.1 + Bot Manager + rate-limiting.
- **Product images** served as private blobs; access via App Service Managed Identity
  (Storage Blob Data Reader). Anonymous public blob access is disabled.
- **ACR image immutability** enforced via Azure Policy assignment.
- **Terraform runner** granted `Key Vault Secrets Officer` (not Administrator)
  post-provisioning. Remove this role assignment after initial secret seeding.

### Networking
- **NAT Gateway** provides static outbound IPs on both App Service subnets.
- **NSGs** on every subnet with explicit deny-all default.
  Port 80 inbound is **not** permitted — Front Door uses HTTPS-only forwarding.
- **VNet integration** (`WEBSITE_VNET_ROUTE_ALL=1`) forces all App Service
  egress through the VNet (and out via NAT Gateway).
- **Azure Bastion** (Standard SKU, zone-redundant) replaces any public jump-box.

### Compute
- **Zone-redundant** App Service Plans (P2v3 / P1v3) with **deployment slots**
  (production + staging) for blue/green swap deployments.
- **Autoscale** configured on both plans with CPU-based scale-out/in rules.
  Scale events notify the ops email address.

### Data
- **Azure SQL General Purpose** — zone-redundant, geo-redundant backup,
  35-day PITR, long-term retention (weekly/monthly/yearly).
- **Redis Premium P1** — zone-redundant, RDB persistence enabled, TLS-only.
  RDB backups stored in a storage account using Managed Identity (no keys in state).

### Observability
- **Log Analytics Workspace** (workspace-based App Insights) — 90-day retention.
- **Availability web tests** from 5 geographic locations.
- **Azure Monitor alerts** for HTTP 5xx, CPU thresholds, failed requests.
- **Diagnostic settings** on every resource type, including storage account access logs.

### CI/CD Integration
- **Azure Front Door Premium** handles global routing, WAF, and CDN.
  App Services are connected via **private link** from Front Door to prevent
  direct internet access.
- Images are built by **GitHub Actions**, pushed to **ACR Premium**
  (private endpoint, content trust enabled, immutable tags enforced via Policy).
- Deployment via `az webapp deploy` or `azd deploy` targeting the **staging slot**,
  then swapped to production after health checks pass.

---

## Terraform State Security

State is encrypted at rest in Azure Blob Storage. To limit blast radius if state
is accessed:
- The state storage account has `shared_access_key_enabled = false` (use Entra
  authentication only).
- RBAC on the state container is scoped to the pipeline service principal only.
- Enable Azure Defender for Storage on the tfstate account.

**Residual risk**: Sensitive values (connection strings, JWT secret) written to Key
Vault via `azurerm_key_vault_secret` are present as sensitive Terraform state
entries. These are protected by state encryption and strict RBAC. For zero-secret-
in-state, pre-create secrets outside Terraform and reference them via
`data "azurerm_key_vault_secret"`.

---

## Provider Lock File

After running `terraform init`, commit `.terraform.lock.hcl`:

```bash
terraform providers lock \
  -platform=linux_amd64 \
  -platform=darwin_arm64 \
  -platform=windows_amd64
git add .terraform.lock.hcl
git commit -m "chore: pin provider checksums"
```

Ensure `.terraform.lock.hcl` is **not** listed in `.gitignore`.

---

## Module Dependency Graph

```
monitoring
    │
    ▼
network ──────────────────────────────────┐
    │                                      │
    ▼                                      │
compute ──────────────────────────────────┤
    │  (provides managed identity IDs)     │
    ▼                                      │
security ◄────────────────────────────────┤
    │  (provides KV URI, ACR, RBAC)        │
    ▼                                      │
database ◄────────────────────────────────┤
    │  (provides Redis + SQL conn strings) │
    ▼                                      │
ci_cd ◄───────────────────────────────────┘
    (provides Front Door, WAF, DNS)
```

---

## Sensitive Variables

The following variables are marked `sensitive = true` and must **never** be
committed to source control:

| Variable | How to supply |
|----------|---------------|
| `sql_admin_password` | `TF_VAR_sql_admin_password` env var — used only at server creation by Azure management plane; Entra-only auth is enabled so this password cannot be used to authenticate to SQL |
| `subscription_id` | `TF_VAR_subscription_id` or `ARM_SUBSCRIPTION_ID` |
| `tenant_id` | `TF_VAR_tenant_id` or `ARM_TENANT_ID` |

SQL application user passwords and the JWT secret are **generated by Terraform**
(`random_password`) and written directly to Key Vault — they are never stored
in tfvars.

---

## GitHub Actions CI/CD Integration

The existing `.github/workflows/dotnetcore.yml` workflow should be extended to:

1. **Build** — `dotnet build` (already present)
2. **Test** — `dotnet test` (already present)
3. **Docker build + push to ACR** — `az acr build` or `docker build && docker push`
4. **Deploy to staging slot** — `az webapp deploy --slot staging`
5. **Smoke test staging** — hit `/health` endpoint
6. **Swap slots** — `az webapp deployment slot swap`

Required GitHub Secrets:
- `AZURE_CLIENT_ID` — Federated identity credential (OIDC recommended)
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `ACR_LOGIN_SERVER` — from `terraform output acr_login_server`

---

## Outputs Reference

| Output | Description |
|--------|-------------|
| `vnet_id` | VNet resource ID |
| `web_app_name` | Web App Service name |
| `web_app_hostname` | Web App default hostname |
| `api_app_name` | API App Service name |
| `api_app_hostname` | API App default hostname |
| `key_vault_uri` | Key Vault URI |
| `acr_login_server` | ACR login server |
| `front_door_endpoint_hostname` | Front Door endpoint hostname |
| `app_insights_connection_string` | App Insights connection string (sensitive) |
| `nat_gateway_public_ip` | Static NAT Gateway IP (allowlist in 3rd-party systems) |

---

## Cost Estimate (approximate, East US 2, production sizing)

| Resource | SKU | ~Monthly USD |
|----------|-----|-------------|
| App Service Plan (Web) | P2v3 × 2–6 instances | $280–$840 |
| App Service Plan (API) | P1v3 × 2–4 instances | $140–$280 |
| Azure SQL (Catalog) | GP Gen5 4 vCore | $370 |
| Azure SQL (Identity) | GP Gen5 2 vCore | $185 |
| Azure Cache for Redis | Premium P1 | $190 |
| Azure Front Door | Premium | $335+ |
| Azure Bastion | Standard | $140 |
| Key Vault | Standard | ~$5 |
| Container Registry | Premium | $50 |
| Log Analytics | PerGB (est. 5 GB/day) | $115 |
| **Total (estimate)** | | **~$1,810–$2,510/mo** |

Costs vary by traffic, data egress, and autoscale activity.
