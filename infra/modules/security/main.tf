# ---------------------------------------------------------------------------
# Service Account — Cloud Run
# ---------------------------------------------------------------------------
resource "google_service_account" "cloudrun" {
  project      = var.project_id
  account_id   = "sa-cloudrun-reporting"
  display_name = "Cloud Run — Django Reporting App"
  description  = "Least-privilege SA used by the Cloud Run service."
}

# ---------------------------------------------------------------------------
# Service Account — Cloud Build
# ---------------------------------------------------------------------------
resource "google_service_account" "cloudbuild" {
  project      = var.project_id
  account_id   = "sa-cloudbuild-reporting"
  display_name = "Cloud Build — Django Reporting App"
  description  = "SA used by Cloud Build for image builds and deployments."
}

# ---------------------------------------------------------------------------
# IAM — Cloud Run SA Roles
# ---------------------------------------------------------------------------

# Cloud SQL Client — project-level with IAM condition scoped to instance name prefix
resource "google_project_iam_member" "cloudrun_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloudrun.email}"

  condition {
    title       = "cloudrun-sql-instance-only"
    description = "Restrict Cloud SQL client access to the reporting instance only"
    expression  = "resource.name.startsWith(\"projects/${var.project_id}/instances/${var.db_instance_name_prefix}\")"
  }
}

# Secret Manager Secret Accessor — scoped to the specific db-password secret ONLY
resource "google_secret_manager_secret_iam_member" "cloudrun_db_password_accessor" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.db_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloudrun.email}"
}

# Cloud Logging Log Writer
resource "google_project_iam_member" "cloudrun_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloudrun.email}"
}

# Cloud Monitoring Metric Writer
resource "google_project_iam_member" "cloudrun_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.cloudrun.email}"
}

# Cloud Trace Agent
resource "google_project_iam_member" "cloudrun_trace_agent" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.cloudrun.email}"
}

# Storage Object Admin scoped to the PDF bucket only
resource "google_storage_bucket_iam_member" "cloudrun_pdf_bucket_admin" {
  bucket = var.pdf_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.cloudrun.email}"
}

# ---------------------------------------------------------------------------
# IAM — Cloud Build SA Roles
# ---------------------------------------------------------------------------

# Artifact Registry Writer — scoped to the SPECIFIC repository only
resource "google_artifact_registry_repository_iam_member" "cloudbuild_artifact_writer" {
  project    = var.project_id
  location   = var.region
  repository = var.artifact_registry_repo_id
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.cloudbuild.email}"
}

# Cloud Run Developer — deploy new revisions
resource "google_project_iam_member" "cloudbuild_run_developer" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

# Storage Object Viewer — read Cloud Build cache bucket
resource "google_project_iam_member" "cloudbuild_storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

# Cloud Build SA needs to act as the Cloud Run SA to deploy services with it
resource "google_service_account_iam_member" "cloudbuild_impersonate_cloudrun" {
  service_account_id = google_service_account.cloudrun.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cloudbuild.email}"
}

# Cloud Build SA must be able to read the DB password secret — scoped to secret only
resource "google_secret_manager_secret_iam_member" "cloudbuild_db_password_accessor" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.db_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloudbuild.email}"
}

# Cloud SQL Client for Cloud Build migration step — same instance-scoped condition
resource "google_project_iam_member" "cloudbuild_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"

  condition {
    title       = "cloudbuild-sql-instance-only"
    description = "Restrict Cloud SQL client access to the reporting instance only"
    expression  = "resource.name.startsWith(\"projects/${var.project_id}/instances/${var.db_instance_name_prefix}\")"
  }
}

# Cloud Logging log writer for Cloud Build
resource "google_project_iam_member" "cloudbuild_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

# ---------------------------------------------------------------------------
# Secret Manager — DB Password Secret
# The secret resource shell is created here.
# The actual secret VALUE must be populated out-of-band (see README).
# Terraform NEVER writes the password value to state.
#
# CMEK: customer_managed_encryption ensures the secret payload is encrypted
# with the operator-supplied KMS key rather than Google-managed key material.
# ---------------------------------------------------------------------------
resource "google_secret_manager_secret" "db_password" {
  project   = var.project_id
  secret_id = "db-password"

  labels = var.labels

  replication {
    auto {
      # CMEK — encrypt secret payload with operator-supplied KMS key.
      # The KMS key must exist and the Secret Manager service agent must have
      # roles/cloudkms.cryptoKeyEncrypterDecrypter on the key before apply.
      customer_managed_encryption {
        kms_key_name = var.kms_key_name
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Audit Log Config — enable Data Access logs on Secret Manager
# ---------------------------------------------------------------------------
resource "google_project_iam_audit_config" "secretmanager_audit" {
  project = var.project_id
  service = "secretmanager.googleapis.com"

  audit_log_config {
    log_type = "DATA_READ"
  }

  audit_log_config {
    log_type = "DATA_WRITE"
  }

  audit_log_config {
    log_type = "ADMIN_READ"
  }
}

# ---------------------------------------------------------------------------
# Audit Log Config — enable Data Access logs on Cloud Storage
# ---------------------------------------------------------------------------
resource "google_project_iam_audit_config" "storage_audit" {
  project = var.project_id
  service = "storage.googleapis.com"

  audit_log_config {
    log_type = "DATA_READ"
  }

  audit_log_config {
    log_type = "DATA_WRITE"
  }

  audit_log_config {
    log_type = "ADMIN_READ"
  }
}
