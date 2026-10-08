output "github_actions_workflow_path" {
  description = "Path to the generated GitHub Actions CI/CD workflow file."
  value       = local_file.github_workflow_ci.filename
}

output "github_actions_pr_workflow_path" {
  description = "Path to the generated GitHub Actions PR checks workflow file."
  value       = local_file.github_workflow_pr.filename
}
