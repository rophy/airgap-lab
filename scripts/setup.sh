#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/.."
VM_NAME="${1:-airgap-lab}"

echo "=== Air-Gap Lab Setup ==="
echo ""

# Step 1: Start local registry
echo "[1/4] Starting local registry..."
docker compose -f "${PROJECT_DIR}/docker-compose.yaml" up -d

# Step 2: Load images into registry
echo "[2/4] Loading images into registry..."
"${SCRIPT_DIR}/load-images.sh" "${PROJECT_DIR}/images/required.txt"

# Step 3: Create multipass VM
echo "[3/4] Creating multipass VM..."
"${PROJECT_DIR}/vm/create-vm.sh" "${VM_NAME}"

# Step 4: Apply firewall lockdown
echo "[4/4] Applying air-gap lockdown..."
multipass exec "${VM_NAME}" -- sudo bash -c "$(cat "${SCRIPT_DIR}/lockdown.sh")"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  multipass shell ${VM_NAME}    # SSH into the VM"
