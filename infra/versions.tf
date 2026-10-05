terraform {
  required_version = ">= 1.7.0"

  # ---------------------------------------------------------------------------
  # Remote state — GCS backend with CMEK encryption.
  # The bucket MUST be created and locked down BEFORE running `terraform init`.
  #
  # REQUIRED: Supply backend configuration via backend.hcl (do NOT commit).
  # Run: terraform init -backend-config=backend.hcl -lockfile=readonly
  #
  # In CI, a missing backend.hcl or a stale/absent .terraform.lock.hcl MUST
  # be treated as a pipeline failure:
  #   terraform init -backend-config=backend.hcl -lockfile=readonly || exit 1
  #
  # The -lockfile=readonly flag prevents unreviewed provider upgrades — any
  # provider version change requires a deliberate `terraform init -upgrade`
  # followed by a code review and commit of the updated .terraform.lock.hcl.
  #
  # See backend.hcl (template — fill in and exclude from source control) for
  # the bucket, prefix, and encryption_key values.
  # ---------------------------------------------------------------------------
  backend "gcs" {}

  required_providers {
    google = {
      source  = "hashicorp/google"
      # Pinned to 5.30.x — patch-level only; commit .terraform.lock.hcl.
      # To upgrade: terraform init -upgrade, review diff, commit lock file.
      version = "~> 5.30"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.30"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}
