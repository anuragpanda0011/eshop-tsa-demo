# ---------------------------------------------------------------------------
# Artifact Registry — Docker Repository
# Vulnerability scanning is enabled via the Container Analysis API
# (containeranalysis.googleapis.com must be enabled — see main.tf API list).
# ---------------------------------------------------------------------------
resource "google_artifact_registry_repository" "reporting" {
  project       = var.project_id
  location      = var.region
  repository_id = var.artifact_registry_repo_id
  description   = "Docker image repository for Django reporting application"
  format        = "DOCKER"
  mode          = "STANDARD_REPOSITORY"

  labels = var.labels

  cleanup_policies {
    id     = "keep-minimum-versions"
    action = "KEEP"

    most_recent_versions {
      keep_count = var.artifact_registry_keep_count
    }
  }

  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"

    condition {
      tag_state  = "UNTAGGED"
      older_than = "336h" # 14 days
    }
  }
}

# ---------------------------------------------------------------------------
# Data source — validate that a real Cloud Armor security policy exists
# when cloudrun_allow_unauthenticated = true.
# This is only looked up when waf_policy_acknowledged = true, ensuring
# that the policy name refers to an actual deployed resource.
# ---------------------------------------------------------------------------
data "google_compute_security_policy" "waf" {
  count   = var.waf_policy_acknowledged && var.cloud_armor_policy_name != "" ? 1 : 0
  project = var.project_id
  name    = var.cloud_armor_policy_name
}

# ---------------------------------------------------------------------------
# Cloud Run Service
# Uses a pinned placeholder image on first deploy.
# Subsequent deploys are handled by Cloud Build.
#
# INGRESS: Set to INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER so that only traffic
# arriving via the HTTPS Load Balancer (and Cloud Armor WAF) is accepted.
# Direct internet access to the Cloud Run URL is rejected at the network layer.
# ---------------------------------------------------------------------------
resource "google_cloud_run_v2_service" "reporting" {
  project  = var.project_id
  name     = var.cloudrun_service_name
  location = var.region

  labels = var.labels

  # Restrict ingress to load balancer only — enforces WAF path at network layer.
  # INGRESS_TRAFFIC_ALL is NOT used; traffic must arrive via the HTTPS LB.
  ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    service_account = var.cloudrun_service_account_email

    scaling {
      min_instance_count = var.cloudrun_min_instances
      max_instance_count = var.cloudrun_max_instances
    }

    vpc_access {
      connector = var.vpc_connector_id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    timeout = "${var.cloudrun_timeout_seconds}s"

    max_instance_request_concurrency = var.cloudrun_concurrency

    containers {
      # Pinned placeholder image — replaced by Cloud Build after first deploy
      # (lifecycle.ignore_changes). The digest below is the official Cloud Run
      # hello container. Verify with:
      #   gcloud artifacts docker images describe \
      #     us-docker.pkg.dev/cloudrun/container/hello:latest \
      #     --show-package-vulnerability
      # Replace this digest after verifying it resolves to the expected image.
      image = "us-docker.pkg.dev/cloudrun/container/hello@sha256:3afe6a647b93a3c67bfcc47e0c5d68e15c4cffefe5a1dad3ceab40c98e19df64"

      resources {
        limits = {
          cpu    = var.cloudrun_cpu
          memory = var.cloudrun_memory
        }
        cpu_idle          = false
        startup_cpu_boost = true
      }

      env {
        name  = "DJANGO_SETTINGS_MODULE"
        value = var.django_settings_module
      }

      env {
        name  = "DB_HOST"
        value = var.db_host
      }

      env {
        name  = "DB_NAME"
        value = var.db_name
      }

      env {
        name  = "DB_USER"
        value = var.db_user
      }

      env {
        name  = "GCS_BUCKET_NAME"
        value = var.pdf_bucket_name
      }

      env {
        name  = "PORT"
        value = "8080"
      }

      env {
        name  = "PYTHONUNBUFFERED"
        value = "1"
      }

      # DB Password — fetched from Secret Manager at runtime; never in plaintext env.
      # Version is pinned to "1" (not "latest") to prevent silent credential rotation.
      # When rotating: add a new Secret Manager version, update this number, redeploy.
      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = var.db_password_secret_id
            # SECURITY: pinned to explicit version — do NOT use "latest".
            # Increment this value and redeploy when the secret is rotated.
            version = "1"
          }
        }
      }

      ports {
        container_port = 8080
        name           = "http1"
      }

      startup_probe {
        http_get {
          path = "/healthz/"
          port = 8080
        }
        initial_delay_seconds = 10
        period_seconds        = 10
        failure_threshold     = 5
        timeout_seconds       = 5
      }

      liveness_probe {
        http_get {
          path = "/healthz/"
          port = 8080
        }
        initial_delay_seconds = 30
        period_seconds        = 30
        failure_threshold     = 3
        timeout_seconds       = 5
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      template[0].labels,
      client,
      client_version,
    ]

    # Precondition 1: WAF acknowledgement must be true when allowing unauthenticated access.
    precondition {
      condition     = !var.cloudrun_allow_unauthenticated || var.waf_policy_acknowledged
      error_message = "cloudrun_allow_unauthenticated=true requires waf_policy_acknowledged=true AND a real Cloud Armor policy name supplied via cloud_armor_policy_name."
    }

    # Precondition 2: When WAF is acknowledged, a real security policy must be resolvable.
    # The data source lookup above will fail at plan time if the named policy does not exist,
    # providing an automated check beyond the boolean flag.
    precondition {
      condition     = !var.waf_policy_acknowledged || length(data.google_compute_security_policy.waf) > 0
      error_message = "waf_policy_acknowledged=true but no Cloud Armor security policy named '${var.cloud_armor_policy_name}' was found in project ${var.project_id}. Deploy the policy before applying."
    }
  }

  depends_on = [
    google_artifact_registry_repository.reporting,
  ]
}

# ---------------------------------------------------------------------------
# Cloud Run IAM — public invoker (only when allow_unauthenticated = true)
# IMPORTANT: ingress=INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER means allUsers
# can only invoke via the HTTPS LB + Cloud Armor path; direct URL access
# is blocked at the network layer regardless of this IAM binding.
# ---------------------------------------------------------------------------
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  count = var.cloudrun_allow_unauthenticated ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.reporting.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
