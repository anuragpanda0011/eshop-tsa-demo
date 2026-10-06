output "service_principal_app_id" {
  description = "App ID of the GitHub Actions Azure service principal."
  value       = azuread_application.github_actions.client_id
}

output "service_principal_object_id" {
  description = "Object ID of the GitHub Actions service principal."
  value       = azuread_service_principal.github_actions.object_id
}

output "federated_credential_name_main" {
  description = "Federated credential name for main branch."
  value       = azuread_application_federated_identity_credential.main_branch.display_name
}

output "federated_credential_name_pr" {
  description = "Federated credential name for pull requests."
  value       = azuread_application_federated_identity_credential.pull_request.display_name
}

output "github_workflow_content" {
  description = "Generated GitHub Actions workflow YAML content."
  value       = local_file.github_workflow.content
  sensitive   = false
}
