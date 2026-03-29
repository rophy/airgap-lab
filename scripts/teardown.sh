#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

echo "=== Air-Gap Lab Teardown ==="
echo ""

# Remove internet NAT if present (sudo)
sudo "${SCRIPT_DIR}/internet.sh" close 2>/dev/null || true

# Destroy VM (sudo)
echo "Deleting VM '${VM_NAME}'..."
if virsh dominfo "${VM_NAME}" &>/dev/null; then
  sudo virsh destroy "${VM_NAME}" 2>/dev/null || true
  sudo virsh undefine "${VM_NAME}" --remove-all-storage 2>/dev/null || true
  sudo rm -f "${VM_LIBVIRT_DIR}/${VM_NAME}-seed.iso"
  echo "  VM removed."
else
  echo "  VM not found, skipping."
fi

# Remove bridge (sudo)
echo "Removing bridge ${BRIDGE_NAME}..."
if ip link show "${BRIDGE_NAME}" &>/dev/null; then
  sudo ip link set "${BRIDGE_NAME}" down
  sudo ip link delete "${BRIDGE_NAME}"
  echo "  Bridge removed."
else
  echo "  Bridge not found, skipping."
fi

# Stop registry (no sudo)
echo "Stopping local registry..."
docker compose -f "${SCRIPT_DIR}/../docker-compose.yaml" down

echo ""
read -rp "Remove registry data volume? (y/N) " answer
if [[ "${answer}" =~ ^[Yy]$ ]]; then
  docker volume rm airgap-lab_registry-data 2>/dev/null || true
  echo "Registry volume removed."
else
  echo "Registry volume preserved."
fi

echo ""
echo "Teardown complete."
