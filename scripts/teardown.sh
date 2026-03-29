#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/.."
VM_NAME="${1:-airgap-lab}"

echo "=== Air-Gap Lab Teardown ==="
echo ""

# Delete multipass VM
echo "Deleting VM '${VM_NAME}'..."
multipass delete "${VM_NAME}" --purge 2>/dev/null || echo "  VM not found, skipping."

# Stop registry
echo "Stopping local registry..."
docker compose -f "${PROJECT_DIR}/docker-compose.yaml" down

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
