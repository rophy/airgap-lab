#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

echo "=== Air-Gap Lab Setup ==="
echo ""

# Step 1: Download cloud image
CACHED_IMAGE="${VM_IMAGE_CACHE}/ubuntu-noble-cloudimg-amd64.img"
echo "[1/5] Downloading Ubuntu cloud image..."
mkdir -p "${VM_IMAGE_CACHE}"
if [[ -f "${CACHED_IMAGE}" ]]; then
  echo "  Already cached, skipping."
else
  wget -q --show-progress -O "${CACHED_IMAGE}" "${VM_IMAGE_URL}"
fi

# Step 2: Create libvirt network
echo "[2/5] Creating libvirt network ${NETWORK_NAME}..."
if virsh net-info "${NETWORK_NAME}" &>/dev/null; then
  echo "  Network already exists, skipping."
else
  NETWORK_XML_RENDERED="/tmp/airgap-network-${NETWORK_NAME}.xml"
  sed \
    -e "s|NETWORK_NAME|${NETWORK_NAME}|g" \
    -e "s|BRIDGE_NAME|${BRIDGE_NAME}|g" \
    -e "s|BRIDGE_HOST_IP|${BRIDGE_HOST_IP}|g" \
    -e "s|DNS_FORWARDER_1|${DNS_SERVER_1}|g" \
    -e "s|DNS_FORWARDER_2|${DNS_SERVER_2}|g" \
    -e "s|REGISTRY_HOSTNAME|${REGISTRY_HOSTNAME}|g" \
    -e "s|APT_CACHE_HOSTNAME|${APT_CACHE_HOSTNAME}|g" \
    -e "s|AI_GATEWAY_HOSTNAME|${AI_GATEWAY_HOSTNAME}|g" \
    "${SCRIPT_DIR}/../vm/network.xml" > "${NETWORK_XML_RENDERED}"
  virsh net-define "${NETWORK_XML_RENDERED}"
  virsh net-start "${NETWORK_NAME}"
  rm -f "${NETWORK_XML_RENDERED}"
  echo "  Network ${NETWORK_NAME} created (bridge: ${BRIDGE_NAME})."
fi

# Step 3: Create VM
echo "[3/5] Creating VM..."
"${SCRIPT_DIR}/../vm/create-vm.sh"

# Step 4: Start registry
echo "[4/5] Starting local registry..."
docker compose -f "${SCRIPT_DIR}/../docker-compose.yaml" up -d

# Step 5: Load images
echo "[5/5] Loading images into registry..."
"${SCRIPT_DIR}/load-images.sh" "${SCRIPT_DIR}/../images/required.txt"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "VM is air-gapped by default (DNS works, no internet)."
echo ""
echo "Next steps:"
echo "  ssh ubuntu@${BRIDGE_VM_IP}     # SSH into the VM"
echo "  ./scripts/verify.sh             # Verify isolation"
