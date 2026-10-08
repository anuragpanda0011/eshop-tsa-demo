# eShopOnWeb — Production-Grade Azure Terraform Infrastructure

This Terraform project provisions the complete production-grade cloud-native infrastructure
for the **eShopOnWeb** reference application on Microsoft Azure, as described in the
target-state architecture document.

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                    Azure Front Door Standard                      │
│              WAF (OWASP 3.2) + CDN + TLS offload                 │
└──────────────────────────────┬───────────────────────────────────┘
                               │ (internal FQDN origin)
┌──────────────────────────────▼───────────────────────────────────┐
│              Azure Container Apps Environment                      │
│          (VNet-injected, internal load balancer only)             │
│  ┌──────────────────┐          ┌──────────────────────────┐      │
│  │  ca-web           │          │  ca-api                   │      │
│  │  (MVC Storefront) │◄────────►│  (PublicApi / JWT)        │      │
│  └──────────────────┘          └──────────────────────────┘      │
└───────────────┬──────────────────────────┬───────────────────────┘
                │ Private Endpoints         │
    ┌───────────▼────────────┐  ┌──────────▼──────────────────┐
    │  Azure SQL Database     │  │  Azure Cache for Redis       │
    │  catalogdb / identitydb │  │  (Standard C1, TLS)         │
    └─────────────────────────┘  └─────────────────────────────┘
                │
    ┌───────────▼────────────┐
    │  Azure Key Vault        │
    │  (RBAC, Private EP)     │
    └─────────────────────────┘
```

### Modules

| Module | Description |
|--------|-------------|
| `modules/network` | VNet, Subnets, NSGs, NAT Gateway, Azure Bastion, Private DNS Zones, Azure Front Door Standard + WAF, Azure API Management |
| `modules/security` | Key Vault (RBAC), Managed Identities (Web + API + CI/CD), Data Protection Storage, GitHub Actions OIDC |
| `modules/database` | Azure SQL Servers (Catalog + Identity DBs), Azure Cache for Redis, Private Endpoints, Key Vault secrets |
| `modules/compute` | Azure Container Registry (Premium), Container Apps Environment (mTLS enabled), Container Apps (Web + API), Static Web Apps |
| `modules/monitoring` | Log Analytics Workspace, Application Insights (workspace-based), Alert Rules, Action Groups, Availability Tests |
| `modules/ci_cd` | GitHub Actions OIDC role assignments, ACR push/pull RBAC, generated workflow files |

---

## Prerequisites

| Tool | Minimum Version |
|------|----------------|
| Terraform | >= 1.7.0 |
| Azure CLI | >= 2.58.0 |
| GitHub CLI (optional) | >= 2.40.0 |
| Docker | >= 24.0 |
| .NET SDK | 8.0.x |

---

## Quick Start

### 1. Clone and Configure

```bash
git clone https://github.com/your-org/eShopOnWeb.git
cd eShopOnWeb/infra/terraform

cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your real values
```

### 2. Set Up Azure Authentication

```bash
# Login to Azure
az login

# Set the subscription
az account set --subscription "<your-subscription-id>"
```

### 3. Configure Remote State (required for production)

```bash
# Create a storage account for Terraform state — enable CMK in production
az group create --name rg-tfstate --location eastus2
az storage account create \
  --name steshoponwebtfstate \
  --resource-group rg-tfstate \
  --sku Standard_ZRS \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false

az storage container create \
  --name tfstate \
  --account-name steshoponwebtfstate

# Add backend configuration to versions.tf:
# backend "azurerm" {
#   resource_group_name  = "rg-tfstate"
#   storage_account_name = "steshoponwebtfstate"
#   container_name       = "tfstate"
#   key                  = "prod/eshoponweb.tfstate"
#   use_oidc             = true
# }
```

> **Security note**: The Terraform state file contains sensitive values (Redis access key,
> SQL password, App Insights connection string). The backend storage account MUST have:
> - Customer-Managed Key (CMK) encryption enabled
> - Private endpoint and public access disabled
> - RBAC access restricted to the CI/CD service principal only
> - Soft-delete and versioning enabled

### 4. Set Required Secrets

Before deploying, set these secrets in your CI/CD pipeline or environment:

| Variable | Description | Secret |
|----------|-------------|--------|
| `TF_VAR_sql_admin_password` | SQL admin password | ✅ |
| `TF_VAR_jwt_secret_key_value` | Initial JWT signing key | ✅ |
| `TF_VAR_health_probe_token` | Health probe shared token | ✅ |

### 5. Deploy Infrastructure

```bash
# Initialise Terraform
terraform init

# Validate configuration
terraform validate

# Preview changes
terraform plan -out=tfplan

# Apply infrastructure
terraform apply tfplan
```

### 6. Post-Deploy: Inject Redis Credential into Key Vault

After the initial apply, the Redis connection string in Key Vault contains only the
hostname and port. The CI/CD pipeline must inject the access key:

```bash
REDIS_HOST=$(terraform output -raw redis_hostname)
REDIS_PORT=$(terraform output -raw redis_ssl_port)
KV_NAME=$(terraform output -raw key_vault_name)

# Get Redis key (requires Key Vault Secrets Officer)
REDIS_KEY=$(az redis list-keys \
  --name "redis-eshoponweb-prod" \
  --resource-group "rg-eshoponweb-prod" \
  --query primaryKey -o tsv)

az keyvault secret set \
  --vault-name "$KV_NAME" \
  --name "RedisConnectionString" \
  --value "${REDIS_HOST}:${REDIS_PORT},password=${REDIS_KEY},ssl=True,abortConnect=False"
```

### 7. Update GitHub Actions Secrets

After deploying, set these secrets in your GitHub repository
(**Settings → Secrets and variables → Actions**):

| Secret Name | Value Source |
|-------------|-------------|
| `AZURE_CLIENT_ID` | Output: `cicd_service_principal_client_id` from security module |
| `AZURE_TENANT_ID` | Your Azure AD Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Your Azure Subscription ID |

### 8. Configure Container Images

```bash
# Login to ACR
ACR=$(terraform output -raw acr_login_server)
az acr login --name $ACR

# Build and push Web image
docker build -t $ACR/web:latest -f src/Web/Dockerfile .
docker push $ACR/web:latest

# Build and push API image
docker build -t $ACR/publicapi:latest -f src/PublicApi/Dockerfile .
docker push $ACR/publicapi:latest
```

---

## Security Considerations

### Secrets Management

All secrets are stored in Azure Key Vault. No secrets should ever be committed to source control:

- SQL connection strings → Key Vault secrets (Managed Identity auth, no passwords in connection strings)
- Redis connection string → Key Vault secret (access key injected post-deploy by CI/CD)
- JWT signing key → Key Vault secret (rotate via CI/CD pipeline)
- Application Insights connection string → Key Vault secret
- Data Protection storage → Managed Identity blob access (no storage key stored)

### Network Security

- All PaaS services accessible only via private endpoints
- SQL servers have `public_network_access_enabled = false` and Entra-only authentication
- Key Vault has `public_network_access_enabled = false`
- ACR has public access disabled
- Container Apps Environment uses internal load balancer only with mTLS enabled
- Front Door is the sole public ingress point (HTTPS only)
- APIM validates `X-Azure-FDID` header to ensure all traffic transits Front Door

### Identity

- All service-to-service authentication uses Managed Identities (RBAC)
- GitHub Actions uses OIDC (no long-lived credentials)
- SQL Server Entra-only authentication enforced (`azuread_authentication_only = true`)
- No access policies on Key Vault — RBAC only
- Separate KMS keys for storage CMK and application Data Protection

---

## Estimated Azure Costs (Monthly)

| Service | SKU | Estimated Cost |
|---------|-----|----------------|
| Container Apps Environment | Consumption + D4 dedicated | ~$350 |
| Azure SQL Database (×2) | GP_Gen5_2 | ~$300 |
| Azure Cache for Redis | Standard C1 | ~$55 |
| Azure Front Door Standard | Standard | ~$35 |
| Azure Container Registry | Premium | ~$50 |
| Azure Key Vault | Standard | ~$5 |
| Log Analytics Workspace | PerGB2018 (estimated 10 GB/day) | ~$230 |
| Application Insights | Workspace-based | Included in LA |
| Azure Bastion | Standard | ~$140 |
| API Management | Developer | ~$50 |
| Static Web Apps | Standard | ~$9 |
| NAT Gateway | Standard | ~$32 |
| **Total** | | **~$1,256/month** |

*Costs are estimates only. Actual costs depend on traffic, storage, and retention policies.*

---

## Terraform State Management

For production use, configure remote state in Azure Blob Storage with CMK encryption.
Add to `versions.tf`:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "steshoponwebtfstate"
    container_name       = "tfstate"
    key                  = "prod/eshoponweb.tfstate"
    use_oidc             = true
  }
}
```

---

## Contributing

1. All infrastructure changes must go through pull requests
2. `terraform fmt` and `terraform validate` must pass (enforced in PR workflow)
3. `terraform plan` output must be reviewed before merge
4. Security-sensitive changes require two approvals

---

## License

MIT License — see root `LICENSE` file for details.
