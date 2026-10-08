provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
  subscription_id = var.subscription_id
}

# Explicit OIDC configuration on the azuread provider ensures consistent
# workload identity federation authentication in CI/CD pipelines.
# The provider reads AZURE_CLIENT_ID and AZURE_TENANT_ID from the environment
# when use_oidc = true is set, matching the azurerm provider behaviour.
provider "azuread" {
  use_oidc  = true
  tenant_id = var.tenant_id
  client_id = var.cicd_client_id
}

provider "random" {}

provider "local" {}
