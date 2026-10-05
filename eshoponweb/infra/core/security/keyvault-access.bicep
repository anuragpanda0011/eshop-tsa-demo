// ---------------------------------------------------------------------------
// Key Vault — RBAC role assignment (replaces legacy access-policy model)
//
// The access-policy model is being retired in favour of Azure RBAC for Key
// Vault, which aligns with the target architecture (RBAC model, Managed
// Identity).  This module assigns the "Key Vault Secrets User" built-in role
// to the supplied principal so it can read secrets without needing an access
// policy entry.
//
// The legacy accessPolicies child resource is intentionally removed; the
// parent Key Vault must be deployed with properties.enableRbacAuthorization
// set to true (see keyvault.bicep).
// ---------------------------------------------------------------------------

param keyVaultName string
param principalId string

// Built-in role: Key Vault Secrets User (read-only secrets)
// https://learn.microsoft.com/azure/key-vault/general/rbac-guide
var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

// Role assignment scoped to the specific Key Vault resource
resource keyVaultSecretsUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  // Deterministic GUID derived from the scope + role + principal to make the
  // assignment idempotent across repeated deployments.
  name: guid(keyVault.id, principalId, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalId: principalId
    // 'ServicePrincipal' covers both user-assigned and system-assigned
    // Managed Identities as well as service principals.
    principalType: 'ServicePrincipal'
    description: 'Key Vault Secrets User — grants read access to secrets for ${keyVaultName}'
  }
}

output roleAssignmentId string = keyVaultSecretsUserAssignment.id
