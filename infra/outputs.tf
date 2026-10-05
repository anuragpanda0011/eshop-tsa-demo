output "cloud_run_url" {
  description = "The public HTTPS URL of the Cloud Run service."
  value       = module.compute.cloud_run_url
}

output "cloud_run_service_name" {
  description = "Name of the deployed Cloud Run service."
  value       = module.compute.cloud_run_service_name
}

output "artifact_registry_repository" {
  description = "Full Artifact Registry repository path."
  value       = module.compute.artifact_registry_repository
}

output "cloud_sql_instance_name" {
  description = "Cloud SQL instance name."
  value       = module.database.instance_name
}

output "cloud_sql_private_ip" {
  description  = "Private IP address of the Cloud SQL instance."
  value        = module.database.private_ip
  sensitive    = true
}

output "cloud_sql_connection_name" {
  description = "Cloud SQL connection name (project:region:instance)."
  value       = module.database.connection_name
}

output "pdf_bucket_name" {
  description = "Name of the Cloud Storage bucket for PDF reports."
  value       = module.storage.bucket_name
}

output "pdf_bucket_url" {
  description = "gs:// URL of the PDF reports bucket."
  value       = module.storage.bucket_url
}

output "secret_manager_db_password_id" {
  description = "Resource ID of the db-password secret in Secret Manager."
  value       = module.security.db_password_secret_id
}

output "cloudrun_service_account_email" {
  description = "Email of the Cloud Run service account."
  value       = module.security.cloudrun_sa_email
}

output "cloudbuild_service_account_email" {
  description = "Email of the Cloud Build service account."
  value       = module.security.cloudbuild_sa_email
}

output "vpc_name" {
  description = "Name of the VPC network."
  value       = module.network.vpc_name
}

output "vpc_connector_id" {
  description = "Resource ID of the Serverless VPC Access Connector."
  value       = module.network.vpc_connector_id
}

output "cloud_dns_name_servers" {
  description = "Name servers for the Cloud DNS managed zone (if created)."
  value       = module.ci_cd.dns_name_servers
}

output "cloud_build_trigger_id" {
  description = "Cloud Build trigger resource ID."
  value       = module.ci_cd.cloud_build_trigger_id
}

output "post_apply_instructions" {
  description = "Manual steps required after terraform apply."
  value       = <<-EOT
    ============================================================
    POST-APPLY MANUAL STEPS REQUIRED
    ============================================================
    1. Set the DB password in Secret Manager and on the Cloud SQL user:

       DB_PASS=$(openssl rand -base64 32)

       # Store in Secret Manager
       printf '%s' "$DB_PASS" | gcloud secrets versions add db-password \
         --data-file=- --project=<PROJECT_ID>

       # Set on Cloud SQL user via --password-file (not --password flag)
       TMPFILE=$(mktemp) && chmod 600 "$TMPFILE"
       printf '%s' "$DB_PASS" > "$TMPFILE"
       gcloud sql users set-password ${module.database.db_user_name} \
         --instance=${module.database.instance_name} \
         --password-file="$TMPFILE" \
         --project=<PROJECT_ID>
       shred -u "$TMPFILE"
       unset DB_PASS

    2. Update the secret version pin in modules/compute/main.tf:
       After adding the first secret version above, confirm it is version "1".
       If rotating later, update version = "1" to the new version number and
       redeploy Cloud Run.

    3. Connect GitHub repository in Cloud Build console:
       Cloud Build → Triggers → Connect Repository → GitHub

    4. Point your DNS registrar's NS records to:
       ${join(", ", module.ci_cd.dns_name_servers)}
       (only if create_cloud_dns = true)

    5. Deploy Cloud Armor security policy + HTTPS Load Balancer BEFORE setting
       cloudrun_allow_unauthenticated = true and waf_policy_acknowledged = true.
    ============================================================
  EOT
}
