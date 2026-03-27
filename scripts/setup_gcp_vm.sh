#!/bin/bash
# ============================================================
# GCP VM Setup Script for SAP Automation POC
# Usage: ./scripts/setup_gcp_vm.sh
# ============================================================

set -euo pipefail

# ---- CONFIGURE THESE ----
PROJECT_ID="sap-ops-poc-490406"
ORG_ID="1063164377941"  # lekhanlal89-org
VM_NAME="sap-operation-poc-vm"
ZONE="us-central1-a"
MACHINE_TYPE="e2-medium"
IMAGE_FAMILY="ubuntu-2204-lts"
IMAGE_PROJECT="ubuntu-os-cloud"
# --------------------------

echo "==> Authenticating with GCP..."
gcloud auth login

# ---- CREATE PROJECT ----
echo "==> Creating project: ${PROJECT_ID}..."
if gcloud projects describe "${PROJECT_ID}" &>/dev/null; then
  echo "    Project already exists, skipping creation."
else
  if [ -n "${ORG_ID}" ]; then
    gcloud projects create "${PROJECT_ID}" --name="SAP Demo Project" --organization="${ORG_ID}"
  else
    gcloud projects create "${PROJECT_ID}" --name="SAP Demo Project"
  fi
  echo "    Project created successfully."
fi

echo "==> Setting project: ${PROJECT_ID}"
gcloud config set project "${PROJECT_ID}"

# ---- LINK BILLING ACCOUNT ----
echo "==> Looking up billing account for organization..."
BILLING_ACCOUNT_ID=$(gcloud billing accounts list --filter="open=true" --format="value(ACCOUNT_ID)" --limit=1)
if [ -n "${BILLING_ACCOUNT_ID}" ]; then
  echo "    Found billing account: ${BILLING_ACCOUNT_ID}"
  echo "==> Linking billing account to project..."
  gcloud billing projects link "${PROJECT_ID}" --billing-account="${BILLING_ACCOUNT_ID}"
else
  echo "==> ERROR: No active billing account found."
  echo "    Please create a billing account at: https://console.cloud.google.com/billing"
  exit 1
fi

# ---- ENABLE COMPUTE ENGINE API ----
echo "==> Enabling Compute Engine API..."
gcloud services enable compute.googleapis.com

echo "==> Creating VM: ${VM_NAME} in zone ${ZONE}..."
gcloud compute instances create "${VM_NAME}" \
  --zone="${ZONE}" \
  --machine-type="${MACHINE_TYPE}" \
  --image-family="${IMAGE_FAMILY}" \
  --image-project="${IMAGE_PROJECT}" \
  --tags=sap-demo \
  --metadata=startup-script='#!/bin/bash
    apt-get update -y
    apt-get install -y python3 python3-pip'

echo "==> Creating firewall rule for SSH (if not exists)..."
gcloud compute firewall-rules create allow-ssh-sap \
  --allow=tcp:22 \
  --target-tags=sap-demo \
  --description="Allow SSH for SAP POC VMs" 2>/dev/null || echo "Firewall rule already exists."

echo ""
echo "==> VM created. Fetching public IP..."
VM_IP=$(gcloud compute instances describe "${VM_NAME}" \
  --zone="${ZONE}" \
  --format="get(networkInterfaces[0].accessConfigs[0].natIP)")

echo ""
echo "======================================================"
echo "  VM Public IP : ${VM_IP}"
echo "  VM Name      : ${VM_NAME}"
echo "  Zone         : ${ZONE}"
echo "======================================================"
echo ""
echo "Next step — update inventory.ini:"
echo "  Replace VM_PUBLIC_IP with: ${VM_IP}"
echo ""
echo "Test SSH:"
echo "  ssh -i ~/.ssh/id_rsa ubuntu@${VM_IP}"
echo ""
echo "Test Ansible ping:"
echo "  ansible -i inventory.ini sapservers -m ping"
