#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

echo "=== Air-Gap Lab Setup ==="
echo ""

# Step 1: Create dedicated bridge network
echo "[1/5] Creating bridge network ${BRIDGE_NAME}..."
if ip link show "${BRIDGE_NAME}" &>/dev/null; then
  echo "  Bridge already exists, skipping."
else
  sudo ip link add "${BRIDGE_NAME}" type bridge
  sudo ip addr add "${BRIDGE_HOST_IP}/24" dev "${BRIDGE_NAME}"
  sudo ip link set "${BRIDGE_NAME}" up
  echo "  Bridge ${BRIDGE_NAME} created with IP ${BRIDGE_HOST_IP}."
fi

# Step 2: Start local registry
echo "[2/5] Starting local registry..."
docker compose -f "${SCRIPT_DIR}/../docker-compose.yaml" up -d

# Step 3: Load images into registry
echo "[3/5] Loading images into registry..."
"${SCRIPT_DIR}/load-images.sh" "${SCRIPT_DIR}/../images/required.txt"

# Step 4: Create multipass VM
echo "[4/5] Creating multipass VM..."
"${SCRIPT_DIR}/../vm/create-vm.sh"

# Step 5: Apply firewall lockdown
echo "[5/5] Applying air-gap lockdown..."
sudo "${SCRIPT_DIR}/lockdown.sh"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  multipass shell ${VM_NAME}    # SSH into the VM"
