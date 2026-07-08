provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy               = false
      recover_soft_deleted_key_vaults            = true
      purge_soft_deleted_secrets_on_destroy      = false
      purge_soft_deleted_certificates_on_destroy = false
      purge_soft_deleted_keys_on_destroy         = false
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    app_service {
      delete_service_plan_on_destroy = false
    }
  }
  subscription_id = var.subscription_id
}

# azuread and random providers require no special feature blocks.
provider "azuread" {}

provider "random" {}
