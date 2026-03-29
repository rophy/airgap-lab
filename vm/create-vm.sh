#!/usr/bin/env bash
set -euo pipefail

VM_NAME="${1:-airgap-lab}"
CPUS="${AIRGAP_VM_CPUS:-4}"
MEMORY="${AIRGAP_VM_MEMORY:-8G}"
DISK="${AIRGAP_VM_DISK:-40G}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLOUD_INIT="${SCRIPT_DIR}/cloud-init.yaml"

echo "Creating multipass VM: ${VM_NAME}"
echo "  CPUs: ${CPUS}, Memory: ${MEMORY}, Disk: ${DISK}"

multipass launch \
  --name "${VM_NAME}" \
  --cpus "${CPUS}" \
  --memory "${MEMORY}" \
  --disk "${DISK}" \
  --cloud-init "${CLOUD_INIT}" \
  24.04

echo "Waiting for cloud-init to complete..."
multipass exec "${VM_NAME}" -- cloud-init status --wait

echo "VM '${VM_NAME}' is ready."
