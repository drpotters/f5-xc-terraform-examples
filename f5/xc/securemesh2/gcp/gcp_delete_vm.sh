#!/bin/bash

set -euo pipefail

PATTERN="${1:-}"
if [[ -z "$PATTERN" ]]; then
  echo "Usage: $0 <vm-name-pattern>"
  exit 1
fi

# Ensure credentials are set
if [[ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]]; then
  echo "export GOOGLE_APPLICATION_CREDENTIALS credentials before proceeding.. exiting.."
  exit 1
fi

# Activate service account
echo "Authenticating..."
gcloud auth activate-service-account --key-file="$GOOGLE_APPLICATION_CREDENTIALS"

# Get project ID from credentials
PROJECT_ID="vesio-dev-cz"
gcloud config set project "$PROJECT_ID"

echo "Searching for VMs matching '$PATTERN'..."

# List all matching VMs once, across all zones
VM_LIST=$(gcloud compute instances list \
  --filter="name~'^${PATTERN}'" \
  --format="csv[no-heading](name,zone)")

if [[ -z "$VM_LIST" ]]; then
  echo "No matching VMs found."
  exit 0
fi

# Process each matching VM
while IFS=, read -r VM ZONE; do
  echo "Found VM: $VM in $ZONE"

  # Get static IP (if any)
  STATIC_IP=$(gcloud compute instances describe "$VM" --zone="$ZONE" \
    --format="value(networkInterfaces[0].accessConfigs[0].natIP)")

  echo "Deleting VM $VM in the zone $ZONE"
  gcloud compute instances delete "$VM" --zone="$ZONE" --quiet

  if [[ -n "$STATIC_IP" ]]; then
    ADDR_NAME=$(gcloud compute addresses list --filter="address='$STATIC_IP'" --format="value(name)")
    REGION="${ZONE%-*}"

    if [[ -n "$ADDR_NAME" ]]; then
      echo "Releasing static IP: $ADDR_NAME in region $REGION"
      gcloud compute addresses delete "$ADDR_NAME" --region="$REGION" --quiet || true
    fi
  fi
done <<< "$VM_LIST"

echo "Cleanup completed for pattern '$PATTERN'"