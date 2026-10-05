# ---------------------------------------------------------------------------
# Terraform GCS Backend Configuration
#
# DO NOT COMMIT THIS FILE TO SOURCE CONTROL.
# Add backend.hcl to .gitignore.
#
# Usage:
#   terraform init -backend-config=backend.hcl -lockfile=readonly
#
# In CI, treat a missing or stale .terraform.lock.hcl as a pipeline failure:
#   terraform init -backend-config=backend.hcl -lockfile=readonly || exit 1
# ---------------------------------------------------------------------------

# Name of the GCS bucket that holds Terraform state.
# Created manually BEFORE terraform init (see README Prerequisites).
bucket = "tf-state-my-project"

# Object prefix (path) within the bucket for this workspace's state files.
prefix = "django-reporting/state"

# Base64-encoded CMEK key for server-side encryption of the state object.
# Obtain from: gcloud kms keys versions get-public-key ... | base64
# KEEP THIS VALUE SECRET — treat it with the same care as a password.
# encryption_key = "<base64-encoded-CMEK-key>"
