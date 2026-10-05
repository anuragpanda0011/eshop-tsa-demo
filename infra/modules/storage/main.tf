# ---------------------------------------------------------------------------
# Dedicated bucket for GCS access logs (log-of-logs)
# ---------------------------------------------------------------------------
resource "google_storage_bucket" "access_logs" {
  project                     = var.project_id
  name                        = "access-logs-${var.project_id}"
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Versioning enabled — retains deleted/overwritten log objects for audit purposes
  versioning {
    enabled = true
  }

  # CMEK encryption — consistent with production-grade at-rest encryption posture
  encryption {
    default_kms_key_name = var.kms_key_name
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }

  labels = var.labels
}

# ---------------------------------------------------------------------------
# Cloud Storage Bucket — PDF Reports
# ---------------------------------------------------------------------------
resource "google_storage_bucket" "pdf_reports" {
  project                     = var.project_id
  name                        = "${var.pdf_bucket_name_prefix}-${var.project_id}"
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  # CMEK encryption
  encryption {
    default_kms_key_name = var.kms_key_name
  }

  # Access logging — records object reads/writes on this bucket
  logging {
    log_bucket        = google_storage_bucket.access_logs.name
    log_object_prefix = "pdf-reports/"
  }

  # Lifecycle rules: NEARLINE → COLDLINE → DELETE
  lifecycle_rule {
    condition {
      age = var.pdf_bucket_nearline_days
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = var.pdf_bucket_coldline_days
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = var.pdf_bucket_delete_days
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 3
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  # CORS — explicit origins only; wildcard '*' is rejected by variable validation
  cors {
    origin          = var.cors_allowed_origins
    method          = ["GET", "HEAD", "OPTIONS"]
    response_header = ["Content-Type", "Content-Disposition"]
    max_age_seconds = 3600
  }

  labels = var.labels
}

# NOTE: The google_storage_bucket_iam_binding with members=[] and
# ignore_changes=[members] has been REMOVED. It was ineffective (Terraform
# never enforced the binding after first apply) and could conflict with
# the google_storage_bucket_iam_member resources in the security module.
# IAM for the PDF bucket is managed exclusively via the security module's
# google_storage_bucket_iam_member resources.

# ---------------------------------------------------------------------------
# Cloud Storage Bucket — Cloud Build Cache
# ---------------------------------------------------------------------------
resource "google_storage_bucket" "cloudbuild_cache" {
  project                     = var.project_id
  name                        = "cloudbuild-cache-${var.project_id}"
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Versioning enabled — allows recovery of accidentally overwritten cache objects
  versioning {
    enabled = true
  }

  # CMEK encryption — consistent with production-grade at-rest encryption posture
  encryption {
    default_kms_key_name = var.kms_key_name
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  labels = var.labels
}
