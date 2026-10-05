output "github_actions_app_id" {
  value = azuread_application.github_actions.id
}

output "github_actions_client_id" {
  value = azuread_application.github_actions.client_id
}

output "github_actions_sp_object_id" {
  value = azuread_service_principal.github_actions.object_id
}

output "federated_credential_main_id" {
  value = azuread_application_federated_identity_credential.github_main.id
}

output "federated_credential_pr_id" {
  value = azuread_application_federated_identity_credential.github_pr.id
}
