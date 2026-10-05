# Django Reporting App — GCP Modernisation (Terraform)

This repository contains production-grade Terraform code to deploy a modernised Django
reporting application on Google Cloud Platform, migrated from a legacy single-VM setup.

## Architecture Overview

```
GitHub → Cloud Build → Artifact Registry → Cloud Run (Django/Gunicorn)
                                                ↕                    ↕
                                         Cloud SQL (PostgreSQL HA)  Cloud Storage (PDFs)
                                                ↕
                                         Secret Manager (DB creds)
                                                ↕
                                    VPC + Serverless VPC Connector
```

## Module Layout

```
.
├── main.tf                         # Root: wires all modules together
├── variables.tf                    # Root input variables
├── outputs.tf                      # Root outputs
├── providers.tf                    # Provider configuration
├── versions.tf                     # Version pins + GCS backend
├── backend.hcl                     # Backend config (NOT committed — see below)
├── terraform.tfvars.example        # Example variable values
├── README.md
└── modules/
    ├── network/                    # VPC, subnets, PSA, VPC connector, firewall
    ├── security/                   # Service accounts, IAM bindings, Secret Manager
    ├── database/                   # Cloud SQL PostgreSQL HA instance
    ├── compute/                    # Cloud Run service, Artifact Registry
    ├── storage/                    # Cloud Storage bucket for PDF reports
    ├── ci_cd/                      # Cloud Build trigger, Cloud DNS (optional)
    └── monitoring/                 # Cloud Logging, Monitoring dashboards, Alerting
```

## Prerequisites

1. A GCP project with billing enabled.
2. **Create the Terraform state bucket before running `terraform init`**:
   ```bash
   gsutil mb -p <PROJECT_ID> -l <REGION> -b on gs://<STATE_BUCKET_NAME>
   gsutil versioning set on gs://<STATE_BUCKET_NAME>
   # Restrict access to break-glass principals only:
   gsutil iam set state-bucket-iam.json gs://<STATE_BUCKET_NAME>
   ```
3. **Create a Cloud KMS key ring and keys** for CMEK (Secret Manager, GCS, Logging):
   ```bash
   gcloud kms keyrings create reporting-keyring \
     --location=us-central1 --project=<PROJECT_ID>

   gcloud kms keys create reporting-storage-key \
     --keyring=reporting-keyring --location=us-central1 \
     --purpose=encryption --project=<PROJECT_ID>

   gcloud kms keys create reporting-logging-key \
     --keyring=reporting-keyring --location=us-central1 \
     --purpose=encryption --project=<PROJECT_ID>

   gcloud kms keys create reporting-secrets-key \
     --keyring=reporting-keyring --location=global \
     --purpose=encryption --project=<PROJECT_ID>

   # Grant GCS service account access to the storage CMEK key:
   GCS_SA=$(gsutil kms serviceaccount -p <PROJECT_ID>)
   gcloud kms keys add-iam-policy-binding reporting-storage-key \
     --keyring=reporting-keyring --location=us-central1 \
     --member="serviceAccount:$GCS_SA" \
     --role=roles/cloudkms.cryptoKeyEncrypterDecrypter \
     --project=<PROJECT_ID>

   # Grant Cloud Logging service account access to the logging CMEK key:
   LOGGING_SA=$(gcloud logging cmek-settings describe \
     --project=<PROJECT_ID> --format='value(serviceAccountId)')
   gcloud kms keys add-iam-policy-binding reporting-logging-key \
     --keyring=reporting-keyring --location=us-central1 \
     --member="serviceAccount:$LOGGING_SA" \
     --role=roles/cloudkms.cryptoKeyEncrypterDecrypter \
     --project=<PROJECT_ID>
   ```
4. **Create `backend.hcl`** (do NOT commit to source control — add to `.gitignore`):
   ```hcl
   bucket          = "tf-state-<PROJECT_ID>"
   prefix          = "django-reporting/state"
   encryption_key  = "<base64-encoded-CMEK-key>"
   ```
5. The following APIs enabled (Terraform will enable them automatically):
   - `run.googleapis.com`, `sqladmin.googleapis.com`, `storage.googleapis.com`
   - `secretmanager.googleapis.com`, `artifactregistry.googleapis.com`
   - `cloudbuild.googleapis.com`, `vpcaccess.googleapis.com`
   - `servicenetworking.googleapis.com`, `dns.googleapis.com`
   - `monitoring.googleapis.com`, `logging.googleapis.com`
   - `containeranalysis.googleapis.com` (vulnerability scanning)
6. Terraform >= 1.7.0 installed.
7. `gcloud` CLI authenticated with Application Default Credentials.
8. **Commit `.terraform.lock.hcl`** to source control after `terraform init` to ensure
   reproducible builds.
9. **CI must run** `terraform init -backend-config=backend.hcl -lockfile=readonly` — a
   missing or updated lock file must be treated as a pipeline failure.

## Quick Start

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your project_id, alert_email, cors_allowed_origins,
# kms_key_name, log_bucket_kms_key_name, security_kms_key_name, etc.

# NEVER commit terraform.tfvars or backend.hcl to source control.
echo "terraform.tfvars" >> .gitignore
echo "backend.hcl" >> .gitignore

terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

## Secret Management (Out-of-Band — Required Post-Apply)

Terraform does **not** write the DB password or any TLS key material to state.
After `terraform apply` completes, set the DB password and create the DB user manually:

```bash
# 1. Generate a strong password
DB_PASS=$(openssl rand -base64 32)

# 2. Store in Secret Manager
echo -n "$DB_PASS" | \
  gcloud secrets versions add db-password --data-file=- --project=<PROJECT_ID>

# 3. Set the password on the Cloud SQL user (requires Cloud SQL Admin API access)
#    Use --password-file to avoid plaintext in process args
TMPFILE=$(mktemp)
chmod 600 "$TMPFILE"
printf '%s' "$DB_PASS" > "$TMPFILE"
gcloud sql users set-password reporting_app \
  --instance=<CLOUD_SQL_INSTANCE_NAME> \
  --password-file="$TMPFILE" \
  --project=<PROJECT_ID>
shred -u "$TMPFILE"

# Clear from shell history / environment immediately
unset DB_PASS
```

## Cloud Build GitHub Connection

The GitHub trigger requires a one-time OAuth connection:
Cloud Build → Triggers → Connect Repository → GitHub (in the GCP Console).

## Cloud SQL HA

The instance is configured with `REGIONAL` availability (automatic failover replica).

## Deletion Protection

Cloud SQL has deletion protection enabled. To destroy, set `deletion_protection = false` first.

## CORS on PDF Bucket

Set `cors_allowed_origins` to the exact origins that need signed-URL access
(e.g. `["https://app.example.com"]`). Wildcard `"*"` is explicitly rejected.

## Cloud Run Ingress & WAF

Cloud Run is configured with `ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"`.
This means **all traffic must arrive via the HTTPS Load Balancer**.
A Cloud Armor security policy MUST be attached to the LB backend service before
setting `cloudrun_allow_unauthenticated = true`. The `cloud_armor_policy_name`
variable must reference a real, deployed `google_compute_security_policy`.

## Secret Version Pinning

The Cloud Run service references Secret Manager secret version `"1"` explicitly.
When you rotate the DB password:
1. Add a new secret version: `gcloud secrets versions add db-password --data-file=-`
2. Update `version = "1"` in `modules/compute/main.tf` to the new version number.
3. Redeploy Cloud Run to pick up the new credential.

## Cost Estimate (approximate, us-central1, 730h/month)

| Service | Config | ~USD/month |
|---|---|---|
| Cloud Run | min 1, max 5, 1 vCPU/512MiB | ~$20–80 |
| Cloud SQL | db-g1-small, HA, 20GB SSD | ~$70 |
| Cloud Storage | 10GB standard | ~$0.23 |
| Secret Manager | 1 secret, low access | ~$0.06 |
| Artifact Registry | ~5GB Docker images | ~$0.50 |
| Cloud Build | 120 free min/day | ~$0 |
| VPC Connector | 2 min instances | ~$15 |
| Cloud KMS | 3 keys, low ops | ~$0.18 |
| **Total** | | **~$105–165/month** |
