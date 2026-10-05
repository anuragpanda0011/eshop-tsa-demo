# ── Azure AD Application for GitHub Actions OIDC ──────────────────────────────
resource "azuread_application" "github_actions" {
  display_name = "sp-github-actions-${var.project}-${var.environment}"

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
      type = "Scope"
    }
  }
}

resource "azuread_service_principal" "github_actions" {
  client_id                    = azuread_application.github_actions.client_id
  app_role_assignment_required = false

  tags = ["github-actions", var.project, var.environment]
}

# ── Federated Identity Credentials (OIDC) ─────────────────────────────────────
# main branch pushes
resource "azuread_application_federated_identity_credential" "github_main" {
  application_id = azuread_application.github_actions.id
  display_name   = "github-main-${var.github_repo}"
  description    = "GitHub Actions OIDC for main branch of ${var.github_org}/${var.github_repo}"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${var.github_branch}"
}

# pull request checks
resource "azuread_application_federated_identity_credential" "github_pr" {
  application_id = azuread_application.github_actions.id
  display_name   = "github-pr-${var.github_repo}"
  description    = "GitHub Actions OIDC for pull requests of ${var.github_org}/${var.github_repo}"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_org}/${var.github_repo}:pull_request"
}

# prod environment
resource "azuread_application_federated_identity_credential" "github_env_prod" {
  application_id = azuread_application.github_actions.id
  display_name   = "github-env-prod-${var.github_repo}"
  description    = "GitHub Actions OIDC for prod environment of ${var.github_org}/${var.github_repo}"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_org}/${var.github_repo}:environment:production"
}

# ── RBAC Assignments for GitHub Actions SP ────────────────────────────────────

# AcrPush — push images to ACR
resource "azurerm_role_assignment" "github_acr_push" {
  scope                = var.acr_id
  role_definition_name = "AcrPush"
  principal_id         = azuread_service_principal.github_actions.object_id
}

# AcrImageSigner — sign images
resource "azurerm_role_assignment" "github_acr_signer" {
  scope                = var.acr_id
  role_definition_name = "AcrImageSigner"
  principal_id         = azuread_service_principal.github_actions.object_id
}

# Azure ContainerApps Contributor on Web ACA resource only
resource "azurerm_role_assignment" "github_aca_web_contributor" {
  scope                = var.aca_web_id
  role_definition_name = "Azure ContainerApps Contributor"
  principal_id         = azuread_service_principal.github_actions.object_id
}

# Azure ContainerApps Contributor on API ACA resource only
resource "azurerm_role_assignment" "github_aca_api_contributor" {
  scope                = var.aca_api_id
  role_definition_name = "Azure ContainerApps Contributor"
  principal_id         = azuread_service_principal.github_actions.object_id
}

# FIX: Reader scoped to the deployment resource group only — NOT the full subscription.
# This prevents enumeration of all resources across the subscription.
# ARM lookups needed by the workflow are limited to the project resource group.
resource "azurerm_role_assignment" "github_rg_reader" {
  scope                = var.resource_group_id
  role_definition_name = "Reader"
  principal_id         = azuread_service_principal.github_actions.object_id
}

# Key Vault Secrets User — read secrets for deployment
resource "azurerm_role_assignment" "github_kv_reader" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azuread_service_principal.github_actions.object_id
}

# ── GitHub Actions Workflow file (generated as local file) ────────────────────
# All third-party GitHub Actions pinned to immutable SHA digests.
# Digests current as of 2025-01 — re-pin periodically via Dependabot or manual audit.
#
# SECURITY NOTE: The generated workflow uses GitHub repository VARIABLES (vars.)
# for non-secret identifiers (CLIENT_ID, TENANT_ID, SUBSCRIPTION_ID, ACR server,
# resource group name). Set these in GitHub → Settings → Secrets and variables →
# Actions → Variables before running the workflow:
#   AZURE_CLIENT_ID       = <github_actions_client_id output>
#   AZURE_TENANT_ID       = <your tenant ID>
#   AZURE_SUBSCRIPTION_ID = <your subscription ID>
#   ACR_LOGIN_SERVER      = <acr_login_server output>
#   RESOURCE_GROUP        = <resource_group_name output>
#   ACA_WEB_NAME          = ca-web-<project>-<environment>
#   ACA_API_NAME          = ca-api-<project>-<environment>
#   ACA_ENVIRONMENT_NAME  = cae-<project>-<environment>
#   FRONT_DOOR_HOSTNAME   = <front_door_endpoint_hostname output>

resource "local_file" "github_actions_workflow" {
  filename        = "${path.module}/../../.github/workflows/ci-cd.yml"
  file_permission = "0600"
  content         = <<-YAML
# =============================================================================
# eShopOnWeb — CI/CD Pipeline
# Generated by Terraform — do not edit manually.
# All third-party actions pinned to immutable SHA digests.
# Only SHA-tagged images are pushed — no mutable :latest tag.
#
# REQUIRED GITHUB REPOSITORY VARIABLES (Settings → Secrets and variables → Actions → Variables):
#   AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID,
#   ACR_LOGIN_SERVER, RESOURCE_GROUP, ACA_WEB_NAME, ACA_API_NAME,
#   ACA_ENVIRONMENT_NAME, FRONT_DOOR_HOSTNAME
# =============================================================================
name: CI/CD Pipeline

on:
  push:
    branches: ["${var.github_branch}"]
  pull_request:
    branches: ["${var.github_branch}"]

permissions:
  id-token: write      # Required for OIDC token exchange
  contents: read
  packages: write
  security-events: write

env:
  ACR_LOGIN_SERVER: $${{ vars.ACR_LOGIN_SERVER }}
  AZURE_SUBSCRIPTION_ID: $${{ vars.AZURE_SUBSCRIPTION_ID }}
  AZURE_TENANT_ID: $${{ vars.AZURE_TENANT_ID }}
  AZURE_CLIENT_ID: $${{ vars.AZURE_CLIENT_ID }}
  RESOURCE_GROUP: $${{ vars.RESOURCE_GROUP }}
  ACA_WEB_NAME: $${{ vars.ACA_WEB_NAME }}
  ACA_API_NAME: $${{ vars.ACA_API_NAME }}
  ACA_ENVIRONMENT_NAME: $${{ vars.ACA_ENVIRONMENT_NAME }}

jobs:
  # ── Build & Test ────────────────────────────────────────────────────────────
  build-and-test:
    name: Build & Test
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

      - name: Setup .NET 8
        uses: actions/setup-dotnet@3951f0dfe7a714d2ee2bea24f01c4b1be4e3d5d1  # v4.3.0
        with:
          dotnet-version: "8.0.x"

      - name: Restore dependencies
        run: dotnet restore

      - name: Build
        run: dotnet build --no-restore --configuration Release

      - name: Run unit tests
        run: dotnet test --no-build --configuration Release --verbosity normal --collect:"XPlat Code Coverage" --results-directory ./coverage

      - name: Upload coverage
        uses: codecov/codecov-action@1e68e06f1dbfde0e4cefc87efeba9e4f2c081eef  # v4.5.0
        with:
          directory: ./coverage
          fail_ci_if_error: false

  # ── Security Scan ────────────────────────────────────────────────────────────
  security-scan:
    name: Security Scan
    runs-on: ubuntu-latest
    needs: build-and-test

    steps:
      - name: Checkout
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

      - name: Run Trivy vulnerability scanner (filesystem)
        uses: aquasecurity/trivy-action@18f2af2a72c2a56c0f73c1fb6e5e879f7be3ba1a  # 0.28.0
        with:
          scan-type: "fs"
          scan-ref: "."
          format: "sarif"
          output: "trivy-results.sarif"

      - name: Upload Trivy scan results
        uses: github/codeql-action/upload-sarif@45775bd8235c68ba1b2b4e6b8ce7f998b2b444b7  # v3.28.0
        with:
          sarif_file: "trivy-results.sarif"

  # ── Build & Push Docker Images ───────────────────────────────────────────────
  build-and-push:
    name: Build & Push Container Images
    runs-on: ubuntu-latest
    needs: [build-and-test, security-scan]
    if: github.ref == 'refs/heads/${var.github_branch}' && github.event_name == 'push'
    outputs:
      web-image-tag: $${{ steps.meta-web.outputs.tags }}
      api-image-tag: $${{ steps.meta-api.outputs.tags }}
      image-sha: $${{ github.sha }}

    steps:
      - name: Checkout
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

      - name: Login to Azure (OIDC)
        uses: azure/login@a457da9ea143d694b1b9c7c869ebb7411525dba5  # v2.3.0
        with:
          client-id: $${{ env.AZURE_CLIENT_ID }}
          tenant-id: $${{ env.AZURE_TENANT_ID }}
          subscription-id: $${{ env.AZURE_SUBSCRIPTION_ID }}

      - name: Login to Azure Container Registry
        run: az acr login --name $${{ env.ACR_LOGIN_SERVER }}

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@f7ce87c1d6bead3e36075b2ce75da1f6cc28aaca  # v3.9.0

      - name: Extract metadata (Web)
        id: meta-web
        uses: docker/metadata-action@902fa8ec7d6ecbea8a07b0a573ee46aa2c80b02a  # v5.7.0
        with:
          images: $${{ env.ACR_LOGIN_SERVER }}/eshoponweb/web
          tags: |
            type=sha,format=long

      - name: Build and push Web image
        uses: docker/build-push-action@471d1dc4e07e5cdedd4c2171150001c434a0ef70  # v5.4.0
        with:
          context: ./src/Web
          file: ./src/Web/Dockerfile
          push: true
          tags: $${{ steps.meta-web.outputs.tags }}
          labels: $${{ steps.meta-web.outputs.labels }}
          cache-from: type=registry,ref=$${{ env.ACR_LOGIN_SERVER }}/eshoponweb/web:buildcache
          cache-to: type=registry,ref=$${{ env.ACR_LOGIN_SERVER }}/eshoponweb/web:buildcache,mode=max

      - name: Extract metadata (API)
        id: meta-api
        uses: docker/metadata-action@902fa8ec7d6ecbea8a07b0a573ee46aa2c80b02a  # v5.7.0
        with:
          images: $${{ env.ACR_LOGIN_SERVER }}/eshoponweb/api
          tags: |
            type=sha,format=long

      - name: Build and push API image
        uses: docker/build-push-action@471d1dc4e07e5cdedd4c2171150001c434a0ef70  # v5.4.0
        with:
          context: ./src/PublicApi
          file: ./src/PublicApi/Dockerfile
          push: true
          tags: $${{ steps.meta-api.outputs.tags }}
          labels: $${{ steps.meta-api.outputs.labels }}
          cache-from: type=registry,ref=$${{ env.ACR_LOGIN_SERVER }}/eshoponweb/api:buildcache
          cache-to: type=registry,ref=$${{ env.ACR_LOGIN_SERVER }}/eshoponweb/api:buildcache,mode=max

      - name: Scan Web image with Trivy
        uses: aquasecurity/trivy-action@18f2af2a72c2a56c0f73c1fb6e5e879f7be3ba1a  # 0.28.0
        with:
          image-ref: "$${{ env.ACR_LOGIN_SERVER }}/eshoponweb/web:sha-$${{ github.sha }}"
          format: "sarif"
          output: "trivy-web.sarif"
          exit-code: "1"
          severity: "CRITICAL,HIGH"

      - name: Scan API image with Trivy
        uses: aquasecurity/trivy-action@18f2af2a72c2a56c0f73c1fb6e5e879f7be3ba1a  # 0.28.0
        with:
          image-ref: "$${{ env.ACR_LOGIN_SERVER }}/eshoponweb/api:sha-$${{ github.sha }}"
          format: "sarif"
          output: "trivy-api.sarif"
          exit-code: "1"
          severity: "CRITICAL,HIGH"

  # ── Deploy to Azure Container Apps ───────────────────────────────────────────
  deploy:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: build-and-push
    environment: production
    if: github.ref == 'refs/heads/${var.github_branch}' && github.event_name == 'push'

    steps:
      - name: Login to Azure (OIDC)
        uses: azure/login@a457da9ea143d694b1b9c7c869ebb7411525dba5  # v2.3.0
        with:
          client-id: $${{ env.AZURE_CLIENT_ID }}
          tenant-id: $${{ env.AZURE_TENANT_ID }}
          subscription-id: $${{ env.AZURE_SUBSCRIPTION_ID }}

      - name: Install ACA extension
        run: az extension add --name containerapp --upgrade --yes

      - name: Deploy Web Container App revision
        run: |
          az containerapp update \
            --name $${{ env.ACA_WEB_NAME }} \
            --resource-group $${{ env.RESOURCE_GROUP }} \
            --image $${{ env.ACR_LOGIN_SERVER }}/eshoponweb/web:sha-$${{ github.sha }} \
            --set-env-vars "DEPLOYMENT_SHA=$${{ github.sha }}"

      - name: Deploy API Container App revision
        run: |
          az containerapp update \
            --name $${{ env.ACA_API_NAME }} \
            --resource-group $${{ env.RESOURCE_GROUP }} \
            --image $${{ env.ACR_LOGIN_SERVER }}/eshoponweb/api:sha-$${{ github.sha }} \
            --set-env-vars "DEPLOYMENT_SHA=$${{ github.sha }}"

      - name: Wait for Web deployment to stabilise
        run: |
          az containerapp revision list \
            --name $${{ env.ACA_WEB_NAME }} \
            --resource-group $${{ env.RESOURCE_GROUP }} \
            --query "[?properties.active].{name:name,replicas:properties.replicas}" \
            --output table

      - name: Run smoke tests
        run: |
          echo "Running smoke tests against production..."
          curl -sSf --retry 5 --retry-delay 10 \
            -H "User-Agent: CI-SmokeTest/1.0" \
            "https://$${{ vars.FRONT_DOOR_HOSTNAME }}/health" | grep -q '"status":"Healthy"'

      - name: Logout of Azure
        if: always()
        run: az logout

  # ── BlazorAdmin SWA Deploy ────────────────────────────────────────────────────
  deploy-blazor-admin:
    name: Deploy BlazorAdmin to Static Web Apps
    runs-on: ubuntu-latest
    needs: build-and-test
    if: github.ref == 'refs/heads/${var.github_branch}' && github.event_name == 'push'

    steps:
      - name: Checkout
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

      - name: Setup .NET 8
        uses: actions/setup-dotnet@3951f0dfe7a714d2ee2bea24f01c4b1be4e3d5d1  # v4.3.0
        with:
          dotnet-version: "8.0.x"

      - name: Publish BlazorAdmin
        run: |
          dotnet publish src/BlazorAdmin/BlazorAdmin.csproj \
            --configuration Release \
            --output ./publish/blazoradmin

      - name: Deploy to Azure Static Web Apps
        uses: Azure/static-web-apps-deploy@4f0e7bd0f1a07c3dfe4dab9591f7e7de00a0a9b0  # v1
        with:
          azure_static_web_apps_api_token: $${{ secrets.SWA_DEPLOYMENT_TOKEN }}
          repo_token: $${{ secrets.GITHUB_TOKEN }}
          action: "upload"
          app_location: "./publish/blazoradmin/wwwroot"
          skip_api_build: true
YAML
}
