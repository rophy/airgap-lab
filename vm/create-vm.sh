#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

CLOUD_INIT_TEMPLATE="${SCRIPT_DIR}/cloud-init.yaml"
CLOUD_INIT_RENDERED="/tmp/airgap-cloud-init-${VM_NAME}.yaml"

# Render cloud-init with config values
sed \
  -e "s|BRIDGE_HOST_IP|${BRIDGE_HOST_IP}|g" \
  -e "s|REGISTRY_PORT|${REGISTRY_PORT}|g" \
  "${CLOUD_INIT_TEMPLATE}" > "${CLOUD_INIT_RENDERED}"

echo "Creating multipass VM: ${VM_NAME}"
echo "  CPUs: ${VM_CPUS}, Memory: ${VM_MEMORY}, Disk: ${VM_DISK}"
echo "  Network: ${BRIDGE_NAME}"

multipass launch \
  --name "${VM_NAME}" \
  --cpus "${VM_CPUS}" \
  --memory "${VM_MEMORY}" \
  --disk "${VM_DISK}" \
  --network "name=${BRIDGE_NAME}" \
  --cloud-init "${CLOUD_INIT_RENDERED}" \
  24.04

rm -f "${CLOUD_INIT_RENDERED}"

echo "Waiting for cloud-init to complete..."
multipass exec "${VM_NAME}" -- cloud-init status --wait

echo "VM '${VM_NAME}' is ready."
