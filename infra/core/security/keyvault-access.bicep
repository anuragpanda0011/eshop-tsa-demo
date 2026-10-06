// keyvault-access.bicep
// Grants a principal RBAC-based access to Key Vault secrets.
// The legacy access-policy model is preserved as a fallback param; RBAC is the default.
param keyVaultName string
param principalId string

// RBAC model (preferred): assign a built-in role to the principal
// 'Key Vault Secrets User' role definition ID: 4633458b-17de-408a-b874-0445c86b69e6
// 'Key Vault Secrets Officer' role definition ID: b86a8fe4-44ce-4948-aee5-eccb2c155cd7
@allowed([
  'SecretsUser'    // read-only  (default — least privilege for app identities)
  'SecretsOfficer' // read/write (for deployment pipelines that create secrets)
])
param roleAssignmentType string = 'SecretsUser'

// Legacy access-policy fallback (set to true only when Key Vault RBAC is not enabled)
param useLegacyAccessPolicy bool = false
param legacyPermissions object = { secrets: [ 'get', 'list' ] }

// Access-policy action — only used in legacy mode
@allowed([ 'add', 'replace', 'remove' ])
param accessPolicyAction string = 'add'

var secretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'
var secretsOfficerRoleId = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
var selectedRoleId = roleAssignmentType == 'SecretsOfficer' ? secretsOfficerRoleId : secretsUserRoleId

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

// RBAC role assignment (preferred path)
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!useLegacyAccessPolicy) {
  // Deterministic GUID scoped to vault + principal + role
  name: guid(keyVault.id, principalId, selectedRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', selectedRoleId)
    principalId: principalId
    // Specify principal type to avoid AAD propagation race conditions
    principalType: 'ServicePrincipal'
  }
}

// Legacy access-policy path (only when RBAC is not enabled on the vault)
resource keyVaultAccessPolicies 'Microsoft.KeyVault/vaults/accessPolicies@2022-07-01' = if (useLegacyAccessPolicy) {
  parent: keyVault
  name: accessPolicyAction
  properties: {
    accessPolicies: [
      {
        objectId: principalId
        tenantId: subscription().tenantId
        permissions: legacyPermissions
      }
    ]
  }
}

output roleAssignmentId string = !useLegacyAccessPolicy ? roleAssignment.id : ''
