# eShopOnWeb — Production-Grade Azure Infrastructure (Terraform)

This Terraform project provisions the complete target-state cloud-native infrastructure for the **eShopOnWeb** ASP.NET Core 8 e-commerce application on Microsoft Azure.

---

## Architecture Overview

```
Internet
  │
  ▼
Azure Front Door Standard (WAF + CDN + Global Load Balancing)
  │
  ├── /api/*      → Azure Container Apps: ca-api  (PublicApi)
  ├── /admin/*    → Azure Static Web Apps (BlazorAdmin)
  ├── /images/*   → Azure Blob Storage   (Product Images, 7-day CDN cache)
  └── /*          → Azure Container Apps: ca-web  (MVC Storefront)
                        │
                        ▼
               Azure Virtual Network (10.0.0.0/16)
               ├── snet-aca-infra      (10.0.0.0/23) — Container Apps Env
               ├── snet-aca-apps       (10.0.2.0/23) — Container Apps workloads
               ├── snet-privateendpoints (10.0.4.0/24) — All Private Endpoints
               ├── snet-redis          (10.0.5.0/28) — Redis (NSG: port 6380 only)
               ├── snet-appgw          (10.0.6.0/26) — Reserved
               ├── AzureBastionSubnet  (10.0.7.0/26) — Bastion
               ├── snet-devops         (10.0.8.0/28) — Runners
               └── snet-management     (10.0.9.0/28) — Jump VMs
```

---

## Security Hardening Applied (vs. prior version)

| Control | Change |
|---|---|
| SQL AAD-only auth | `azuread_authentication_only = true` on both SQL servers; password auth disabled |
| Redis key not in state | `redis-connection-string` KV secret contains hostname/port/SSL only; key injected out-of-band |
| Vuln-assessment: no SAS/key | SQL server system-assigned MI gets `Storage Blob Data Contributor` on the container; no account key or SAS |
| Storage: key access disabled | `shared_access_key_enabled = false`; all access via RBAC |
| WAF rate-limit fixed | Corrected negation logic; global 150 req/min + sensitive-path 30 req/min rules |
| Redis NSG | New `nsg-redis` allowing only port 6380 from ACA subnets; associated with `snet-redis` |
| ACA NSG lateral movement | Replaced broad `VirtualNetwork/*` rule with targeted port 8080 from PE subnet only |
| PE NSG Redis port | `Allow-Redis-Subnet-Inbound` restricted to port 6380 only |
| ACR content trust | `trust_policy { enabled = true }` |
| ACR secondary zone redundancy | `zone_redundancy_enabled = true` on replication |
| NSG flow logs | Network Watcher + flow logs for all NSGs → dedicated storage + Traffic Analytics |
| Storage blob audit | `azurerm_monitor_diagnostic_setting` on blob sub-resource |
| Blob lifecycle policy | Archive/delete rules for images and vulnerability-assessment containers |
| CI/CD action SHAs | All `uses:` pinned to full commit SHAs |
| Trivy scan | `exit-code: '1'` — HIGH/CRITICAL findings fail the build; no `|| true` |
| Image tags | `:latest` push removed; SHA tag only |
| Resource group protection | `prevent_deletion_if_contains_resources = true` |
| Workflow file path | Uses `path.root` (not `../../` traversal) |
| LAW CMK | Optional dedicated cluster + CMK, controlled by `enable_law_cmk` variable |
| `local` provider | Declared in `versions.tf` |
| Default images removed | `web_image`/`api_image` have no default; CI/CD must supply SHA-tagged refs |

---

## Residual Risks (cannot be fully fixed in Terraform)

| Risk | Mitigation |
|---|---|
| Redis access key in Terraform state | `primary_access_key` is a sensitive attribute always stored in state. Ensure state backend is encrypted (Azure Blob with encryption + RBAC, no public access). Use `az redis list-keys` post-deploy to inject key to KV out-of-band, or migrate the application to AAD token auth (StackExchange.Redis ≥ 2.6 + `ConfigurationOptions.ConfigureForAzureWithTokenCredential`). |
| Standard Redis has no persistence | RDB/AOF backup requires Premium SKU. Acceptable for a cache tier; document recovery procedure (cache warm-up on restart). |
| Log Analytics CMK costs ~$400/month | Enabled via `enable_law_cmk = true`. Disabled by default; enable for regulated workloads. |
| Lock file not committed | Run `terraform init` and commit `.terraform.lock.hcl` to source control. |

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
    ├── database/
    ├── compute/
    ├── monitoring/
    └── ci_cd/
```

---

## Prerequisites

| Tool | Minimum Version |
|------|----------------|
| Terraform | 1.7.0 |
| Azure CLI | 2.60.0 |
| az container-apps extension | latest |
| Docker | 24.x |

---

## Deployment Steps

### 1. Authenticate to Azure

```bash
az login
az account set --subscription "<your-subscription-id>"
```

### 2. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — supply web_image and api_image as SHA-tagged refs
```

**Required variables (no defaults):**

| Variable | Description |
|---|---|
| `subscription_id` | Azure Subscription ID |
| `sql_admin_login` | SQL admin login (sensitive) |
| `sql_admin_password` | Strong SQL admin password (min 32 chars) |
| `alert_email` | Ops team email for alerts |
| `github_org` | GitHub organisation name |
| `github_repo_name` | GitHub repository name |
| `web_image` | SHA-tagged web image (set by CI/CD after first build) |
| `api_image` | SHA-tagged API image (set by CI/CD after first build) |

### 3. Initialise Terraform

```bash
terraform init
# IMPORTANT: commit .terraform.lock.hcl to source control
git add .terraform.lock.hcl
```

### 4. Validate

```bash
terraform validate
terraform fmt -recursive
```

### 5. Plan and Apply

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

### 6. Post-Deploy: Inject Redis Access Key

Because `shared_access_key_enabled = false` prevents Terraform from embedding the Redis key, inject it to Key Vault manually after first apply:

```bash
REDIS_KEY=$(az redis list-keys \
  --name redis-eshoponweb-prod \
  --resource-group rg-eshoponweb-prod \
  --query primaryKey -o tsv)

az keyvault secret set \
  --vault-name kv-eshoponweb-prod \
  --name redis-access-key \
  --value "$REDIS_KEY"
```

Then restart the container apps to pick up the new secret:

```bash
az containerapp revision restart \
  --name ca-web-eshoponweb-prod \
  --resource-group rg-eshoponweb-prod
```

### 7. Configure GitHub Actions Secrets

| Secret Name | Value |
|---|---|
| `AZURE_CLIENT_ID` | `cicd_service_principal_app_id` output |
| `AZURE_TENANT_ID` | Your Azure Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Your Subscription ID |
| `ACR_NAME` | ACR name |
| `ACR_LOGIN_SERVER` | `acr_login_server` output |
| `AZURE_RESOURCE_GROUP` | `resource_group_name` output |
| `ACA_WEB_NAME` | `ca-web-eshoponweb-prod` |
| `ACA_API_NAME` | `ca-api-eshoponweb-prod` |
| `AZURE_STATIC_WEB_APPS_API_TOKEN` | From Azure Portal → Static Web Apps |

---

## State Management

Configure remote state backend before `terraform init`:

```hcl
# backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstateeshoponweb"
    container_name       = "tfstate"
    key                  = "eshoponweb/prod/terraform.tfstate"
    use_oidc             = true
  }
}
```

```bash
az group create -n rg-tfstate -l eastus2
az storage account create -n sttfstateeshoponweb -g rg-tfstate \
  --sku Standard_GRS \
  --min-tls-version TLS1_2 \
  --https-only true \
  --allow-blob-public-access false
az storage container create -n tfstate --account-name sttfstateeshoponweb
```

---

## License

MIT — see `LICENSE` file.
