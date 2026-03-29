#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

echo "=== Air-Gap Lab Teardown ==="
echo ""

# Remove internet NAT if present (sudo)
sudo "${SCRIPT_DIR}/internet.sh" close 2>/dev/null || true

# Destroy VM
echo "Deleting VM '${VM_NAME}'..."
if virsh dominfo "${VM_NAME}" &>/dev/null; then
  virsh destroy "${VM_NAME}" 2>/dev/null || true
  virsh undefine "${VM_NAME}" --remove-all-storage 2>/dev/null || true
  rm -f "${VM_LIBVIRT_DIR}/${VM_NAME}-seed.iso"
  echo "  VM removed."
else
  echo "  VM not found, skipping."
fi

# Remove libvirt network
echo "Removing network ${NETWORK_NAME}..."
if virsh net-info "${NETWORK_NAME}" &>/dev/null; then
  virsh net-destroy "${NETWORK_NAME}" 2>/dev/null || true
  virsh net-undefine "${NETWORK_NAME}" 2>/dev/null || true
  echo "  Network removed."
else
  echo "  Network not found, skipping."
fi

# Stop services
echo "Stopping registry and apt cache..."
docker compose -f "${SCRIPT_DIR}/../docker-compose.yaml" down

echo ""
read -rp "Remove data volumes (registry + apt cache)? (y/N) " answer
if [[ "${answer}" =~ ^[Yy]$ ]]; then
  docker volume rm airgap-lab_registry-data airgap-lab_apt-cache-data 2>/dev/null || true
  echo "Volumes removed."
else
  echo "Volumes preserved."
fi

echo ""
echo "Teardown complete."
