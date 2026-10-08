# ===========================================================================
# CI/CD Module
# Provisions: Minimum-privilege role assignments for GitHub Actions OIDC SP,
#             ACR push/pull roles, Container App deployment roles,
#             Key Vault Secrets Officer scope,
#             and supporting GitHub Actions workflow configuration outputs.
# ===========================================================================

locals {
  prefix = "${var.project}-${var.environment}"
}

data "azurerm_client_config" "current" {}

# ---------------------------------------------------------------------------
# Resource Group Reader (least-privilege: discover resources only)
# Removed the broad "Contributor" assignment at RG scope.
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "cicd_rg_reader" {
  scope                = var.resource_group_id
  role_definition_name = "Reader"
  principal_id         = var.cicd_service_principal_object_id
}

# ---------------------------------------------------------------------------
# ACR Push role for CI/CD (to push newly built images)
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "cicd_acr_push" {
  scope                = var.acr_id
  role_definition_name = "AcrPush"
  principal_id         = var.cicd_service_principal_object_id
}

# ACR Pull for reading (needed by deployment verification)
resource "azurerm_role_assignment" "cicd_acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = var.cicd_service_principal_object_id
}

# ---------------------------------------------------------------------------
# Container Apps — scoped Contributor on individual apps only
# (not at resource-group level — prevents modification of other resources)
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "cicd_web_ca_contributor" {
  scope                = var.web_container_app_id
  role_definition_name = "Contributor"
  principal_id         = var.cicd_service_principal_object_id
}

resource "azurerm_role_assignment" "cicd_api_ca_contributor" {
  scope                = var.api_container_app_id
  role_definition_name = "Contributor"
  principal_id         = var.cicd_service_principal_object_id
}

# ---------------------------------------------------------------------------
# Key Vault Secrets Officer — CI/CD reads/writes secrets during deploy
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "cicd_kv_secrets_officer" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.cicd_service_principal_object_id
}

# ---------------------------------------------------------------------------
# GitHub Actions Workflow files are generated as local files for reference.
# ---------------------------------------------------------------------------
resource "local_file" "github_workflow_ci" {
  filename = "${path.root}/.github/workflows/ci-cd.yml"
  content = templatefile("${path.module}/templates/ci-cd.yml.tftpl", {
    acr_login_server    = var.acr_login_server
    resource_group_name = var.resource_group_name
    subscription_id     = var.subscription_id
    web_ca_name         = "ca-web-${local.prefix}"
    api_ca_name         = "ca-api-${local.prefix}"
    environment         = var.environment
    project             = var.project
  })
  file_permission = "0644"
}

resource "local_file" "github_workflow_pr" {
  filename        = "${path.root}/.github/workflows/pr-checks.yml"
  content         = file("${path.module}/templates/pr-checks.yml.tftpl")
  file_permission = "0644"
}
