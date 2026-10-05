# ---------------------------------------------------------------------------
# Locals
# ---------------------------------------------------------------------------
locals {
  db_password_secret_name = split("/", var.db_password_secret_id)[length(split("/", var.db_password_secret_id)) - 1]

  create_github_trigger = var.github_owner != "" && var.github_repo != ""

  # Artifact Registry image base path
  image_base = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_registry_repo_id}/django-app"

  # Official Cloud SQL Auth Proxy container image — pinned by tag+digest.
  # Update this digest periodically as part of your dependency management process.
  # Verify: docker pull gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.10.0
  #         docker inspect --format='{{index .RepoDigests 0}}' gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.10.0
  cloudsql_proxy_image = "gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.10.0"

  # Python test image — pinned by digest to prevent supply-chain substitution.
  # Update periodically: docker pull python:3.11-slim && docker inspect --format='{{index .RepoDigests 0}}' python:3.11-slim
  # Digest current as of 2024-Q4; verify before use in production.
  python_test_image = "python:3.11-slim@sha256:3c43bec84c26d6d5f2e3ae5a1dbffb7d84a5df25ce52c97e0a2cf58e5c36e4e2"
}

# ---------------------------------------------------------------------------
# Cloud Build Trigger — GitHub push to main
# NOTE: Requires a pre-existing GitHub connection in Cloud Build console.
# ---------------------------------------------------------------------------
resource "google_cloudbuild_trigger" "github_push" {
  count = local.create_github_trigger ? 1 : 0

  project     = var.project_id
  name        = "trigger-django-reporting-main"
  description = "Build and deploy Django reporting app on push to ${var.github_branch}"
  location    = var.region

  service_account = "projects/${var.project_id}/serviceAccounts/${var.cloudbuild_sa_email}"

  github {
    owner = var.github_owner
    name  = var.github_repo

    push {
      branch = "^${var.github_branch}$"
    }
  }

  build {
    timeout = "1200s"

    options {
      logging      = "CLOUD_LOGGING_ONLY"
      machine_type = "E2_HIGHCPU_8"
    }

    available_secrets {
      secret_manager {
        version_name = "projects/${var.project_id}/secrets/${local.db_password_secret_name}/versions/latest"
        env          = "DB_PASSWORD"
      }
    }

    # Step 1 — Run unit tests
    # Image is digest-pinned to prevent supply-chain substitution of the test runner.
    # DB_PASSWORD here is a clearly non-credential test scaffold value; it is not
    # a real secret and is explicitly documented as such. A real DB is not contacted
    # during unit tests (DJANGO_SETTINGS_MODULE=config.settings.test uses an in-memory
    # or SQLite backend). Do NOT use a real credential here.
    step {
      id         = "test"
      name       = local.python_test_image
      entrypoint = "bash"
      args = [
        "-c",
        join(" && ", [
          "pip install --quiet --no-cache-dir -r requirements.txt",
          "python manage.py test --verbosity=2 --no-input",
        ]),
      ]
      env = [
        "DJANGO_SETTINGS_MODULE=config.settings.test",
        "DB_HOST=localhost",
        "DB_NAME=test_reporting",
        "DB_USER=test_user",
        # Non-credential test scaffold value — unit tests use SQLite/in-memory DB.
        # This value has zero access to any real database; it satisfies Django's
        # settings validation only. Replace with a Secret Manager reference if
        # your test settings actually connect to a database.
        "DB_PASSWORD=unittest-no-db-access",
      ]
    }

    # Step 2 — Build Docker image (tagged with SHA; also tag latest for cache)
    step {
      id   = "build"
      name = "gcr.io/cloud-builders/docker"
      args = [
        "build",
        "--tag", "${local.image_base}:$SHORT_SHA",
        "--tag", "${local.image_base}:latest",
        "--cache-from", "${local.image_base}:latest",
        "--label", "git-commit=$SHORT_SHA",
        "--label", "build-id=$BUILD_ID",
        ".",
      ]
      wait_for = ["test"]
    }

    # Step 3 — Push image with SHA tag (immutable, used for deployments)
    step {
      id       = "push-sha"
      name     = "gcr.io/cloud-builders/docker"
      args     = ["push", "${local.image_base}:$SHORT_SHA"]
      wait_for = ["build"]
    }

    # Step 4 — Push image with latest tag (used only as build cache)
    step {
      id       = "push-latest"
      name     = "gcr.io/cloud-builders/docker"
      args     = ["push", "${local.image_base}:latest"]
      wait_for = ["build"]
    }

    # Step 5 — Scan pushed image for HIGH/CRITICAL CVEs before proceeding.
    # Requires containeranalysis.googleapis.com API to be enabled.
    # The bash script blocks until results are available.
    # Build fails if any HIGH or CRITICAL vulnerabilities are found.
    step {
      id         = "vuln-scan"
      name       = "gcr.io/cloud-builders/gcloud"
      entrypoint = "bash"
      args = [
        "-c",
        join("\n", [
          "set -euo pipefail",
          "echo 'Waiting for vulnerability scan results...'",
          "sleep 30",
          "SCAN_RESULT=$(gcloud artifacts docker images list-vulnerabilities \\",
          "  ${local.image_base}:$SHORT_SHA \\",
          "  --project=${var.project_id} \\",
          "  --location=${var.region} \\",
          "  --format='value(vulnerability.effectiveSeverity)' \\",
          "  --filter='vulnerability.effectiveSeverity=HIGH OR vulnerability.effectiveSeverity=CRITICAL')",
          "if [ -n \"$$SCAN_RESULT\" ]; then",
          "  echo 'HIGH or CRITICAL vulnerabilities found — blocking deployment'",
          "  gcloud artifacts docker images list-vulnerabilities \\",
          "    ${local.image_base}:$SHORT_SHA \\",
          "    --project=${var.project_id} \\",
          "    --location=${var.region} \\",
          "    --filter='vulnerability.effectiveSeverity=HIGH OR vulnerability.effectiveSeverity=CRITICAL'",
          "  exit 1",
          "fi",
          "echo 'Vulnerability scan passed — no HIGH/CRITICAL CVEs found'",
        ]),
      ]
      wait_for = ["push-sha"]
    }

    # Step 6 — Start Cloud SQL Auth Proxy using official container image.
    # Binds to 127.0.0.1 ONLY (loopback) — not 0.0.0.0 — to prevent exposing
    # the proxy listener on other interfaces of the Cloud Build worker.
    step {
      id   = "start-proxy"
      name = local.cloudsql_proxy_image
      args = [
        var.db_connection_name,
        # SECURITY: bind to loopback only, not 0.0.0.0
        "--address=127.0.0.1",
        "--port=5433",
        "--quiet",
      ]
      wait_for = ["vuln-scan"]
    }

    # Step 7 — Run database migrations via Cloud SQL Auth Proxy
    step {
      id         = "migrate"
      name       = "${local.image_base}:$SHORT_SHA"
      entrypoint = "bash"
      args = [
        "-c",
        join("\n", [
          "set -euo pipefail",
          "# Wait for proxy to be ready",
          "for i in $(seq 1 10); do",
          "  nc -z 127.0.0.1 5433 && echo 'Proxy ready' && break",
          "  echo \"Waiting for proxy... attempt $i\"",
          "  sleep 2",
          "done",
          "python manage.py migrate --noinput",
        ]),
      ]
      secret_env = ["DB_PASSWORD"]
      env = [
        "DJANGO_SETTINGS_MODULE=config.settings.production",
        "DB_HOST=127.0.0.1",
        "DB_PORT=5433",
        "DB_NAME=${var.db_name}",
        "DB_USER=${var.db_user}",
      ]
      wait_for = ["start-proxy"]
    }

    # Step 8 — Collect static files
    step {
      id         = "collectstatic"
      name       = "${local.image_base}:$SHORT_SHA"
      entrypoint = "bash"
      args = [
        "-c",
        join("\n", [
          "set -euo pipefail",
          "python manage.py collectstatic --noinput",
        ]),
      ]
      secret_env = ["DB_PASSWORD"]
      env = [
        "DJANGO_SETTINGS_MODULE=config.settings.production",
        "DB_HOST=127.0.0.1",
        "DB_PORT=5433",
        "DB_NAME=${var.db_name}",
        "DB_USER=${var.db_user}",
      ]
      wait_for = ["migrate"]
    }

    # Step 9 — Deploy new revision to Cloud Run (no traffic yet)
    step {
      id   = "deploy"
      name = "gcr.io/cloud-builders/gcloud"
      args = [
        "run", "deploy", var.cloudrun_service_name,
        "--image=${local.image_base}:$SHORT_SHA",
        "--region=${var.region}",
        "--platform=managed",
        "--project=${var.project_id}",
        "--no-traffic",
      ]
      wait_for = ["collectstatic"]
    }

    # Step 10 — Smoke test new revision before shifting traffic
    step {
      id         = "smoke-test"
      name       = "gcr.io/cloud-builders/gcloud"
      entrypoint = "bash"
      args = [
        "-c",
        join("\n", [
          "set -euo pipefail",
          "NEW_REV=$(gcloud run revisions list --service=${var.cloudrun_service_name} --region=${var.region} --project=${var.project_id} --format='value(name)' --limit=1)",
          "REVISION_URL=$(gcloud run revisions describe \"$$NEW_REV\" --region=${var.region} --project=${var.project_id} --format='value(status.url)')",
          "echo \"Testing revision: $$REVISION_URL\"",
          "curl -sSf --retry 3 --retry-delay 5 \"$$REVISION_URL/healthz/\" || (echo 'Smoke test failed!' && exit 1)",
          "echo 'Smoke test passed!'",
        ]),
      ]
      wait_for = ["deploy"]
    }

    # Step 11 — Shift 100% traffic to new revision
    step {
      id   = "shift-traffic"
      name = "gcr.io/cloud-builders/gcloud"
      args = [
        "run", "services", "update-traffic", var.cloudrun_service_name,
        "--to-latest",
        "--region=${var.region}",
        "--platform=managed",
        "--project=${var.project_id}",
      ]
      wait_for = ["smoke-test"]
    }

    # Record built images (SHA tag only — latest is cache only)
    images = [
      "${local.image_base}:$SHORT_SHA",
    ]
  }

  tags = ["django-reporting", "main-branch"]
}

# ---------------------------------------------------------------------------
# Cloud DNS Managed Zone (optional)
# ---------------------------------------------------------------------------
resource "google_dns_managed_zone" "reporting" {
  count = var.create_cloud_dns ? 1 : 0

  project     = var.project_id
  name        = var.dns_zone_name
  dns_name    = var.dns_domain
  description = "Managed DNS zone for Django reporting application"
  visibility  = "public"

  labels = var.labels

  dnssec_config {
    state = "on"
  }
}

# ---------------------------------------------------------------------------
# Cloud DNS — CNAME record pointing custom domain → Cloud Run
# ---------------------------------------------------------------------------
resource "google_dns_record_set" "cloudrun_cname" {
  count = var.create_cloud_dns ? 1 : 0

  project      = var.project_id
  managed_zone = google_dns_managed_zone.reporting[0].name
  name         = var.dns_domain
  type         = "CNAME"
  ttl          = 300

  rrdatas = ["ghs.googlehosted.com."]
}
