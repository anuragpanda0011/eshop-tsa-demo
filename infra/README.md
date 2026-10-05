# eShopOnWeb — Production-Grade Azure Cloud-Native Terraform

This repository contains a complete, production-grade Terraform project that provisions the
target-state Azure cloud-native architecture for eShopOnWeb.

---

## Architecture Overview

```
Internet
  │
  ▼
Azure DNS (Public Zone: contoso.com)
  │
  ▼
Azure Front Door Premium (WAF + CDN + TLS offload)
  │   OWASP CRS Microsoft_DefaultRuleSet 2.0 + BotManagerRuleSet 1.0, custom rate-limit rules
  │   Static asset caching: /images/*, /css/*, /js/* (7-day TTL)
  │
  ├──► Azure Static Web Apps (BlazorAdmin WASM) — AAD auth enforced by Terraform
  │
  ▼
Azure Container Apps Environment (cae-eshoponweb-prod)
  │   Internal VNet ingress, Zone redundant, Consumption + Dedicated profiles
  │   mTLS enabled at environment level (transport = "auto")
  │
  ├──► ca-web (MVC Storefront)  ←── User-Assigned Managed Identity (web)
  │         min: 2, max: 20 replicas | CPU: 1.0 | RAM: 2Gi
  │
  └──► ca-api (PublicApi)       ←── User-Assigned Managed Identity (api)
            min: 2, max: 15 replicas | CPU: 0.75 | RAM: 1.5Gi
              │
              ▼
        Azure API Management (External VNet mode)
        ←── Dedicated User-Assigned Managed Identity (apim) — separate from api MI
        JWT validation (tenant-specific issuer + audience), rate-limiting, CORS
        Subscription key enforcement enabled
        IP-filter policy restricts to AzureFrontDoor.Backend (WAF bypass prevention)

Azure Virtual Network (10.10.0.0/16)
  ├── snet-aca-infra   10.10.0.0/23  (ACA environment infra)
  ├── snet-aca-apps    10.10.2.0/23  (ACA workload pods)
  ├── snet-pe          10.10.4.0/24  (Private Endpoints)
  ├── snet-appgw       10.10.5.0/26  (Reserved - Application Gateway)
  ├── snet-redis       10.10.6.0/27  (Redis)
  ├── snet-agents      10.10.7.0/26  (GitHub Actions runners)
  ├── AzureBastionSubnet 10.10.8.0/27
  └── snet-apim        10.10.9.0/27  (API Management - External VNet mode)

Private Endpoints (snet-pe):
  ├── Azure SQL Server        → privatelink.database.windows.net
  ├── Azure Cache for Redis   → privatelink.redis.cache.windows.net
  ├── Azure Container Registry → privatelink.azurecr.io
  ├── Azure Key Vault         → privatelink.vaultcore.azure.net
  ├── Azure Blob Storage (Data Protection) → privatelink.blob.core.windows.net
  ├── Azure Blob Storage (Audit)           → privatelink.blob.core.windows.net
  └── Azure Blob Storage (LAW CMK)         → privatelink.blob.core.windows.net

Data Layer:
  ├── Azure SQL Database: catalogdb  (GP_Gen5_2, zone redundant, LTR 5yr, AAD-only auth)
  ├── Azure SQL Database: identitydb (GP_Gen5_2, zone redundant, LTR 5yr, AAD-only auth)
  └── Azure Cache for Redis C1 Standard (SSL-only, port 6379 NSG rule removed)

Security:
  ├── Azure Key Vault (Premium SKU, RBAC model, private endpoint, purge protection)
  ├── User-Assigned Managed Identities (web, api, apim [dedicated], acr-pull)
  ├── Key Vault Secrets: jwt-secret-key, sql connection strings, redis connection string
  └── Key Vault Key: RSA 4096 for ASP.NET Data Protection ring (CMK on ALL storage accounts)

Storage:
  ├── Azure Blob Storage (Data Protection Keys, ZRS, versioning enabled, CMK encrypted, private endpoint)
  ├── Azure Blob Storage (SQL Audit Logs, GRS, versioning enabled, CMK encrypted, private endpoint)
  ├── Azure Blob Storage (LAW CMK, ZRS, versioning enabled, CMK encrypted, private endpoint)
  └── Azure Blob Storage (NSG Flow Logs, ZRS, versioning enabled, CMK encrypted, no public access)

Container Registry:
  └── Azure Container Registry Premium
      Geo-replicated, private endpoint, vulnerability scanning, content trust
      No mutable :latest tags pushed by CI/CD

Observability:
  ├── Azure Log Analytics Workspace (≥90-day retention, CMK-linked storage, single instance)
  ├── Azure Application Insights (workspace-based, distributed tracing, adaptive sampling,
  │   local_authentication_disabled = true — key-based ingestion disabled)
  ├── NSG Flow Logs (all NSGs) with Traffic Analytics
  ├── NSG Diagnostic Settings (all NSGs) — NetworkSecurityGroupEvent + RuleCounter to LAW
  ├── SQL Audit to immutable storage account (CMK) + Log Analytics
  ├── Metric Alerts: CPU, Memory, SQL CPU, Redis memory, Availability, LAW DataCap
  └── Custom Workbook dashboard

CI/CD:
  ├── Azure AD App with OIDC Federated Credentials (correct issuer URL)
  ├── GitHub Actions workflow: build → test → security scan → push ACR → deploy ACA
  │   All third-party actions pinned to immutable SHA digests
  │   Only SHA-tagged images pushed — no mutable :latest tag
  │   Workflow file written with 0600 permissions
  └── RBAC: AcrPush, AcrImageSigner, Azure ContainerApps Contributor (per-app),
      KV Secrets User, Reader scoped to resource group only (NOT subscription)

Networking Security:
  ├── Azure DDoS Network Protection (Standard) — attached directly to VNet resource
  ├── Azure Bastion (Standard SKU, hardened NSG, shareable_link_enabled=false,
  │   file_copy_enabled=false, tunneling_enabled=false) — zero-trust operator access
  ├── NAT Gateway (zone-redundant, deterministic outbound IP for ACA)
  └── NSGs on ALL subnets (including Bastion), flow logs enabled, CMK on flow-log storage
      Diagnostic settings enabled on ALL NSGs (not just PE subnet)

NSG Hardening:
  ├── PE subnet: port-restricted (1433/6380/443 only from legitimate source subnets)
  ├── Agents subnet: deny-all inbound (outbound-only runners)
  ├── AppGW subnet: inbound 443 from AzureFrontDoor.Backend only (not Internet)
  ├── APIM subnet: full required outbound rules + deny-all egress catch-all
  └── Bastion subnet: outbound port 80 to Internet removed
```

---

## Security Hardening Checklist

- [x] All secrets stored in Key Vault — no secrets in code or environment variables
- [x] Key Vault uses RBAC model (not legacy access policies)
- [x] Key Vault Premium SKU — HSM-backed key operations
- [x] Key Vault has private endpoint — no public network access
- [x] Key Vault has lifecycle prevent_destroy = true
- [x] SQL databases have private endpoints — public access disabled
- [x] SQL AAD-only authentication (`azuread_authentication_only = true`)
- [x] SQL admin credentials are internally generated throwaway values (not input variables)
- [x] SQL databases have lifecycle prevent_destroy = true
- [x] Redis has private endpoint — no public access, SSL-only (port 6379 NSG rule removed)
- [x] Redis connection string: lifecycle.ignore_changes does NOT suppress value drift
- [x] ACR Premium with private endpoint — admin login disabled — no :latest tag pushed
- [x] Managed Identities for all service-to-service authentication
- [x] APIM has a dedicated managed identity (separate from API Container App identity)
- [x] APIM IP-filter policy restricts gateway to AzureFrontDoor.Backend (WAF bypass prevention)
- [x] GitHub Actions uses OIDC (no long-lived secrets, correct issuer URL)
- [x] All third-party GitHub Actions pinned to immutable SHA digests
- [x] GitHub Actions Reader role scoped to resource group only (not subscription)
- [x] Front Door WAF in Prevention mode with Microsoft_DefaultRuleSet 2.0 + BotManagerRuleSet (Premium SKU)
- [x] DDoS Protection Standard enabled on VNet (single VNet resource, no duplicate)
- [x] Azure Bastion for operator access — hardened NSG, shareable links disabled, file copy disabled
- [x] NAT Gateway for zone-redundant deterministic outbound IP
- [x] TLS 1.2 minimum enforced everywhere; APIM backend uses https://
- [x] ACA transport = "auto" enabling mTLS at environment level
- [x] Content Trust (image signing) enabled on ACR
- [x] Vulnerability scanning on ACR images via Trivy in CI (pinned SHA)
- [x] Data Protection keys in Blob + CMK-encrypted with Key Vault RSA 4096 key + private endpoint
- [x] Audit storage account: CMK-encrypted, private endpoint, no public access, versioning enabled
- [x] Flow-log storage account: CMK-encrypted, no public access, ZRS replication, versioning enabled
- [x] LAW CMK storage account: CMK-encrypted, private endpoint, no public access, versioning enabled
- [x] Soft delete and purge protection on Key Vault (90-day retention)
- [x] APIM in External VNet mode — not publicly exposed without Front Door + IP filter policy
- [x] APIM JWT validation with tenant-specific issuer and audience
- [x] APIM subscription key enforcement enabled
- [x] APIM NSG: required outbound rules + deny-all egress (External VNet mode compliant)
- [x] NSG flow logs enabled for all NSGs with Traffic Analytics
- [x] NSG diagnostic settings enabled for ALL NSGs (NetworkSecurityGroupEvent + RuleCounter)
- [x] SQL auditing to immutable storage (CMK) + Log Analytics
- [x] Container image tags validated — no mutable/floating tags accepted or pushed
- [x] GitHub Actions SP uses Azure ContainerApps Contributor (not Contributor) on ACA resources
- [x] GitHub Actions SP Reader scoped to resource group (not subscription)
- [x] Web managed identity has Key Vault Crypto User (not Crypto Officer)
- [x] ApplicationInsights connection string passed via KV secret reference, not plaintext env var
- [x] Application Insights local_authentication_disabled = true (key-based ingestion disabled)
- [x] instrumentation_key output removed (replaced by connection_string only)
- [x] Log Analytics Workspace linked to CMK-encrypted storage (single workspace, no duplicate)
- [x] Log Analytics Workspace has lifecycle prevent_destroy = true
- [x] SQL server system MI granted Storage Blob Data Contributor on audit storage account
- [x] PE subnet NSG: port-restricted to 1433/6380/443 from legitimate source subnets only
- [x] Agents subnet NSG: deny-all inbound (runners are outbound-only)
- [x] AppGW subnet NSG: inbound 443 from AzureFrontDoor.Backend (not Internet)
- [x] GitHub Actions workflow file written with 0600 permissions
- [x] Log retention validated ≥90 days in bootstrap module
- [x] Application Insights adaptive sampling configured to prevent LAW quota breach
- [x] Static Web App AAD authentication enforced by Terraform (not manual post-deploy)
- [x] SQL connection string secrets have expiration_date set
- [x] Front Door origin http_port not set to 80 (HTTPS-only origin)
- [x] StorageDelete operations captured in all storage blob diagnostic settings

---

## Module Structure

```
.
├── main.tf
├── variables.tf
├── outputs.tf
├── providers.tf
├── versions.tf
├── terraform.tfvars.example
├── README.md
└── modules/
    ├── network/
    ├── security/
    ├── compute/
    ├── database/
    ├── monitoring/
    ├── monitoring_bootstrap/
    └── ci_cd/
```

---

## Prerequisites

| Tool | Minimum Version |
|------|----------------|
| Terraform | >= 1.7.0 |
| Azure CLI | >= 2.60.0 |
| Azure Provider | >= 3.117.0, < 3.118.0 |
| Azure AD Provider | >= 2.53.0, < 2.54.0 |
| Azure Subscription | Owner or Contributor + User Access Administrator |

---

## Quick Start

### 1. Configure backend state storage

```bash
az group create --name rg-tfstate --location eastus2
az storage account create \
  --name sttfstateeshoponweb \
  --resource-group rg-tfstate \
  --sku Standard_ZRS \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false
az storage account blob-service-properties update \
  --account-name sttfstateeshoponweb \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 30
az storage container create \
  --name tfstate \
  --account-name sttfstateeshoponweb
# REQUIRED: Configure CMK encryption on state storage BEFORE first apply.
# The Redis primary_access_key will be written to state — CMK + strict RBAC
# are MANDATORY to protect it. This is a hard security requirement, not advisory.
az storage account update \
  --name sttfstateeshoponweb \
  --resource-group rg-tfstate \
  --encryption-key-source Microsoft.Keyvault \
  --encryption-key-vault <kv-uri> \
  --encryption-key-name <key-name>

# Restrict state container access to Terraform deployer identity only:
az storage account update \
  --name sttfstateeshoponweb \
  --resource-group rg-tfstate \
  --default-action Deny
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee <terraform-sp-object-id> \
  --scope /subscriptions/<sub-id>/resourceGroups/rg-tfstate/providers/Microsoft.Storage/storageAccounts/sttfstateeshoponweb
```

### 2. Configure variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — NEVER commit this file
```

### 3. Deploy

```bash
az login && az account set --subscription "<your-subscription-id>"
terraform init \
  -backend-config="resource_group_name=rg-tfstate" \
  -backend-config="storage_account_name=sttfstateeshoponweb" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=eshoponweb/prod.tfstate"
terraform validate && terraform plan -out=tfplan && terraform apply tfplan
```

### 4. Two-phase apply (Front Door / ACA dependency)

On first apply, the ACA web FQDN is not yet known. Use:
```bash
terraform apply -target=module.monitoring_bootstrap -target=module.network -target=module.security
terraform apply -target=module.database -target=module.compute
terraform apply  # full apply to wire Front Door origin and monitoring health check
```

---

## Important Post-Deployment Steps

### Redis key rotation (MANDATORY)
The Redis `primary_access_key` is stored in Terraform state. After deployment:
1. State backend MUST use CMK encryption and strict RBAC (enforced before first apply — see Quick Start)
2. Immediately rotate the Redis key via Azure portal or CLI:
   ```bash
   az redis regenerate-keys --name <redis-name> --resource-group <rg> --key-type Primary
   ```
3. Update the Key Vault secret `redis-connection-string` with the new key:
   ```bash
   NEW_KEY=$(az redis list-keys --name <redis-name> --resource-group <rg> --query primaryKey -o tsv)
   az keyvault secret set \
     --vault-name <kv-name> \
     --name redis-connection-string \
     --value "<hostname>:<ssl_port>,password=${NEW_KEY},ssl=True,abortConnect=False"
   ```
4. Restart affected Container Apps to pick up the new connection string
5. On next `terraform apply`, Terraform will update the KV secret value to match the current
   `azurerm_redis_cache.primary_access_key` (lifecycle.ignore_changes on value has been REMOVED)

### Static Web App AAD Authentication
AAD authentication is now configured by Terraform via `azurerm_static_web_app_auth_settings_v2`.
You must supply `swa_aad_client_id` and `swa_aad_client_secret` variables referencing an
Azure AD App Registration with the SWA redirect URI configured:
```
https://<swa-default-hostname>/.auth/login/aad/callback
```

### Configure GitHub Actions secrets/variables

| Secret Name | Value |
|-------------|-------|
| `AZURE_CLIENT_ID` | `terraform output -raw github_actions_client_id` |
| `AZURE_TENANT_ID` | Your Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Your Azure subscription ID |
| `SWA_DEPLOYMENT_TOKEN` | From Azure portal → Static Web App → Manage deployment token |

Move `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` to GitHub Actions **repository variables** (not secrets) for the generated workflow to reference via `vars.` context.
