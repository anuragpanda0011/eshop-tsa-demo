# ---------------------------------------------------------------------------
# Random suffix to ensure globally unique Cloud SQL instance name
# (Cloud SQL instance names cannot be reused for ~7 days after deletion)
# ---------------------------------------------------------------------------
resource "random_id" "db_suffix" {
  byte_length = 4
}

# ---------------------------------------------------------------------------
# Cloud SQL PostgreSQL Instance — HA Regional
# ---------------------------------------------------------------------------
resource "google_sql_database_instance" "main" {
  project             = var.project_id
  name                = "${var.db_instance_name}-${random_id.db_suffix.hex}"
  region              = var.region
  database_version    = var.db_postgres_version
  deletion_protection = var.db_deletion_protection

  settings {
    tier              = var.db_tier
    availability_type = "REGIONAL"   # HA with automatic failover replica
    disk_autoresize   = true
    disk_size         = 20           # GB — initial size; autoresize will grow
    disk_type         = "PD_SSD"

    location_preference {
      zone           = var.zone_primary
      secondary_zone = var.zone_secondary
    }

    ip_configuration {
      ipv4_enabled    = false          # No public IP
      private_network = var.vpc_id
      ssl_mode        = "ENCRYPTED_ONLY"
    }

    backup_configuration {
      enabled                        = true
      start_time                     = "02:00"
      location                       = var.region
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = var.db_pitr_days
      backup_retention_settings {
        retained_backups = var.db_backup_retention_days
        retention_unit   = "COUNT"
      }
    }

    maintenance_window {
      day          = 1    # Sunday
      hour         = 2
      update_track = "stable"
    }

    database_flags {
      name  = "max_connections"
      value = "100"
    }

    database_flags {
      name  = "log_min_duration_statement"
      value = "500"
    }

    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    database_flags {
      name  = "log_lock_waits"
      value = "on"
    }

    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = false
    }

    user_labels = var.labels
  }
}

# ---------------------------------------------------------------------------
# Database
# ---------------------------------------------------------------------------
resource "google_sql_database" "reporting" {
  project  = var.project_id
  instance = google_sql_database_instance.main.name
  name     = var.db_name
  charset  = "UTF8"
}

# ---------------------------------------------------------------------------
# Database User — password managed entirely out-of-band.
#
# SECURITY: We do NOT use google_sql_user with a password attribute here because
# any password value would be stored unredacted in Terraform state, granting
# anyone with state-read access the plaintext DB credential.
#
# Instead:
#   1. The Cloud SQL user is created with no password by Terraform.
#   2. A null_resource with local-exec calls `gcloud sql users set-password`
#      using --password-file to avoid exposing the plaintext password in
#      the process argument list (/proc/<pid>/cmdline).
#   3. The same password is stored in Secret Manager via a separate gcloud call.
#   4. The temp file is shredded immediately after use.
#
# The null_resource runs once on first apply (keyed on instance name).
# Password rotation must be performed out-of-band (see README).
# ---------------------------------------------------------------------------
resource "google_sql_user" "reporting_app" {
  project  = var.project_id
  instance = google_sql_database_instance.main.name
  name     = var.db_user
  # No password attribute — password is set out-of-band via null_resource below.
}

# ---------------------------------------------------------------------------
# Out-of-band password bootstrap:
# Sets the DB user password and stores it in Secret Manager without touching
# Terraform state. This runs once on the first apply.
# Requires: gcloud CLI authenticated with sufficient permissions.
#
# SECURITY: Password is written to a chmod-600 temp file and passed via
# --password-file to avoid the plaintext appearing in the process argument list.
# The temp file is shredded (overwritten + deleted) immediately after use.
# ---------------------------------------------------------------------------
resource "null_resource" "db_password_bootstrap" {
  # Re-runs only if the instance name changes (i.e., on recreation)
  triggers = {
    instance_name = google_sql_database_instance.main.name
    db_user       = google_sql_user.reporting_app.name
  }

  provisioner "local-exec" {
    command = <<-EOF
      set -euo pipefail

      # Generate a 32-byte random password
      DB_PASS=$(openssl rand -base64 32)

      # Write to a restricted temp file — never passed as a CLI argument
      TMPFILE=$(mktemp)
      chmod 600 "$TMPFILE"
      printf '%s' "$DB_PASS" > "$TMPFILE"

      # Set password on Cloud SQL user via --password-file (not --password flag)
      # to prevent the plaintext from appearing in /proc/<pid>/cmdline
      gcloud sql users set-password "${google_sql_user.reporting_app.name}" \
        --instance="${google_sql_database_instance.main.name}" \
        --password-file="$TMPFILE" \
        --project="${var.project_id}" \
        --quiet

      # Store in Secret Manager (creates a new version)
      printf '%s' "$DB_PASS" | \
        gcloud secrets versions add db-password \
          --data-file=- \
          --project="${var.project_id}" \
          --quiet

      # Shred the temp file — overwrite before deletion
      shred -u "$TMPFILE" 2>/dev/null || rm -f "$TMPFILE"
      unset DB_PASS
    EOF

    interpreter = ["bash", "-c"]
  }

  depends_on = [
    google_sql_user.reporting_app,
  ]
}
