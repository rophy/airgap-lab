#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

echo "=== Air-Gap Lab Teardown ==="
echo ""

# Remove firewall rules
echo "Removing firewall rules..."
sudo "${SCRIPT_DIR}/unlock.sh" 2>/dev/null || echo "  No rules to remove."

# Delete multipass VM
echo "Deleting VM '${VM_NAME}'..."
multipass delete "${VM_NAME}" --purge 2>/dev/null || echo "  VM not found, skipping."

# Stop registry
echo "Stopping local registry..."
docker compose -f "${SCRIPT_DIR}/../docker-compose.yaml" down

# Remove bridge
echo "Removing bridge ${BRIDGE_NAME}..."
if ip link show "${BRIDGE_NAME}" &>/dev/null; then
  sudo ip link set "${BRIDGE_NAME}" down
  sudo ip link delete "${BRIDGE_NAME}"
  echo "  Bridge removed."
else
  echo "  Bridge not found, skipping."
fi

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
