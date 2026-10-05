#!/usr/bin/env sh
# Initialises local Azurite emulator resources on first start.
# Idempotent — safe to re-run.
set -euo pipefail

echo "[init] Waiting for Azurite blob endpoint..."
until az storage container list \
      --connection-string "${AZURE_STORAGE_CONNECTION_STRING}" \
      --output none 2>/dev/null; do
  sleep 2
done

echo "[init] Creating blob containers..."
for CONTAINER in dataprotection catalog-images order-attachments; do
  az storage container create \
    --name "${CONTAINER}" \
    --connection-string "${AZURE_STORAGE_CONNECTION_STRING}" \
    --output none \
    --fail-on-exist false || true
  echo "  ✓ container: ${CONTAINER}"
done

echo "[init] Creating queue: order-created"
az storage queue create \
  --name order-created \
  --connection-string "${AZURE_STORAGE_CONNECTION_STRING}" \
  --output none \
  --fail-on-exist false || true

echo "[init] Creating queue: email-notifications"
az storage queue create \
  --name email-notifications \
  --connection-string "${AZURE_STORAGE_CONNECTION_STRING}" \
  --output none \
  --fail-on-exist false || true

echo "[init] Azurite resources ready."
