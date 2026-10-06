provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy          = false
      recover_soft_deleted_key_vaults       = true
      purge_soft_deleted_secrets_on_destroy = false
      recover_soft_deleted_secrets          = true
    }
    resource_group {
      # Prevent accidental destruction of resource groups that still contain
      # resources (SQL servers, Key Vault, Container Apps, etc.).
      prevent_deletion_if_contains_resources = true
    }
  }
  subscription_id = var.subscription_id
}

provider "azuread" {}

provider "random" {}

provider "local" {}
