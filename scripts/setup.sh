#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

echo "=== Air-Gap Lab Setup ==="
echo ""

# Step 1: Download cloud image (no sudo)
CACHED_IMAGE="${VM_IMAGE_CACHE}/ubuntu-noble-cloudimg-amd64.img"
echo "[1/5] Downloading Ubuntu cloud image..."
mkdir -p "${VM_IMAGE_CACHE}"
if [[ -f "${CACHED_IMAGE}" ]]; then
  echo "  Already cached, skipping."
else
  wget -q --show-progress -O "${CACHED_IMAGE}" "${VM_IMAGE_URL}"
fi

# Step 2: Create bridge (sudo)
echo "[2/5] Creating bridge network ${BRIDGE_NAME}..."
if ip link show "${BRIDGE_NAME}" &>/dev/null; then
  echo "  Bridge already exists, skipping."
else
  sudo ip link add "${BRIDGE_NAME}" type bridge
  sudo ip addr add "${BRIDGE_HOST_IP}/24" dev "${BRIDGE_NAME}"
  sudo ip link set "${BRIDGE_NAME}" up
  echo "  Bridge ${BRIDGE_NAME} created with IP ${BRIDGE_HOST_IP}."
fi

# Step 3: Create VM (sudo)
echo "[3/5] Creating VM..."
sudo "${SCRIPT_DIR}/../vm/create-vm.sh"

# Step 4: Start registry (no sudo)
echo "[4/5] Starting local registry..."
docker compose -f "${SCRIPT_DIR}/../docker-compose.yaml" up -d

# Step 5: Load images (no sudo)
echo "[5/5] Loading images into registry..."
"${SCRIPT_DIR}/load-images.sh" "${SCRIPT_DIR}/../images/required.txt"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "VM is air-gapped by default (no internet path)."
echo ""
echo "Next steps:"
echo "  ssh ubuntu@${BRIDGE_VM_IP}     # SSH into the VM (password: ubuntu)"
echo "  ./scripts/verify.sh             # Verify isolation"
