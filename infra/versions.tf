terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Backend is configured via -backend-config=backend.hcl at init time.
  # Do NOT hardcode storage account names here — see backend.hcl.example.
  # Usage: terraform init -backend-config=backend.hcl
  backend "azurerm" {}
}
