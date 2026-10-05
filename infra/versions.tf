terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # FIX: Tightened from ~> 3.117 (allows any 3.x minor) to a narrow range
      # that allows only patch updates within 3.117.x. This prevents unreviewed
      # minor releases from silently changing provider defaults or behavior.
      # Use Renovate or Dependabot to propose deliberate minor version bumps
      # with changelog review before merging.
      version = ">= 3.117.0, < 3.118.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.53.0, < 2.54.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0, < 3.7.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.9.0, < 2.10.0"
    }
  }

  backend "azurerm" {
    # Configure via -backend-config flags or environment variables:
    # resource_group_name  = "rg-tfstate"
    # storage_account_name = "sttfstateeshoponweb"
    # container_name       = "tfstate"
    # key                  = "eshoponweb/prod.tfstate"
    #
    # SECURITY REQUIREMENTS for state backend storage account (MANDATORY):
    #   - min_tls_version = TLS1_2
    #   - allow_blob_public_access = false
    #   - versioning enabled
    #   - Customer-managed key (CMK) encryption — HARD REQUIREMENT:
    #     Redis primary_access_key is written to state in plaintext by the
    #     azurerm provider. Without CMK, this key is exposed to anyone with
    #     storage account read access.
    #   - Access restricted to Terraform deployer identity only via RBAC
    #   - Soft-delete and immutable storage policy enabled
    #   - No shared access key usage (use Azure AD authentication only)
    #   - See README Quick Start for bootstrap commands
  }
}
