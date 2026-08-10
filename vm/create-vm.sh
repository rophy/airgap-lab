#!/usr/bin/env bash
#
# Creates the libvirt VM. No sudo needed (user must be in libvirt group).
# The base cloud image must already exist at VM_IMAGE_CACHE.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

CACHED_IMAGE="${VM_IMAGE_CACHE}/ubuntu-noble-cloudimg-amd64.img"
DISK_IMAGE="${VM_LIBVIRT_DIR}/${VM_NAME}.qcow2"
SEED_ISO="${VM_LIBVIRT_DIR}/${VM_NAME}-seed.iso"

mkdir -p "${VM_LIBVIRT_DIR}"

if [[ ! -f "${CACHED_IMAGE}" ]]; then
  echo "Error: cloud image not found at ${CACHED_IMAGE}"
  echo "Run ./scripts/setup.sh which downloads it first."
  exit 1
fi

# Create disk from cloud image
echo "Creating VM disk (${VM_DISK}G)..."
cp "${CACHED_IMAGE}" "${DISK_IMAGE}"
qemu-img resize "${DISK_IMAGE}" "${VM_DISK}G"

# Render cloud-init and network config
CLOUD_INIT_RENDERED="/tmp/airgap-cloud-init-${VM_NAME}.yaml"
NETWORK_CONFIG_RENDERED="/tmp/airgap-network-config-${VM_NAME}.yaml"

# Find host user's SSH public key
CALLER_HOME=$(eval echo "~${SUDO_USER:-$USER}")
SSH_PUBKEY="${CALLER_HOME}/.ssh/id_ed25519.pub"
[[ ! -f "${SSH_PUBKEY}" ]] && SSH_PUBKEY="${CALLER_HOME}/.ssh/id_rsa.pub"
SSH_KEY_VALUE="[]"
if [[ -f "${SSH_PUBKEY}" ]]; then
  echo "  Injecting SSH key from ${SSH_PUBKEY}"
  SSH_KEY_VALUE="[\"$(cat "${SSH_PUBKEY}")\"]"
fi

sed \
  -e "s|SSH_AUTHORIZED_KEYS|${SSH_KEY_VALUE}|g" \
  "${SCRIPT_DIR}/cloud-init.yaml" > "${CLOUD_INIT_RENDERED}"

sed \
  -e "s|BRIDGE_VM_IP|${BRIDGE_VM_IP}|g" \
  -e "s|BRIDGE_HOST_IP|${BRIDGE_HOST_IP}|g" \
  "${SCRIPT_DIR}/network-config.yaml" > "${NETWORK_CONFIG_RENDERED}"

# Generate cloud-init seed ISO
echo "Generating cloud-init seed ISO..."
cloud-localds -N "${NETWORK_CONFIG_RENDERED}" "${SEED_ISO}" "${CLOUD_INIT_RENDERED}"

rm -f "${CLOUD_INIT_RENDERED}" "${NETWORK_CONFIG_RENDERED}"

# Create VM with only the airgap network
echo "Creating VM: ${VM_NAME}"
echo "  CPUs: ${VM_CPUS}, Memory: ${VM_MEMORY}M, Disk: ${VM_DISK}G"
echo "  Network: ${NETWORK_NAME} (${BRIDGE_VM_IP})"

virt-install \
  --name "${VM_NAME}" \
  --vcpus "${VM_CPUS}" \
  --memory "${VM_MEMORY}" \
  --disk "path=${DISK_IMAGE},format=qcow2" \
  --disk "path=${SEED_ISO},device=cdrom" \
  --network "network=${NETWORK_NAME},model=virtio" \
  --os-variant ubuntu24.04 \
  --graphics none \
  --noautoconsole \
  --import

echo "Waiting for VM to boot..."
for i in $(seq 1 60); do
  if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=2 -o BatchMode=yes "ubuntu@${BRIDGE_VM_IP}" true 2>/dev/null; then
    echo "VM '${VM_NAME}' is ready at ${BRIDGE_VM_IP}."
    exit 0
  fi
  sleep 2
done

echo "Warning: VM created but SSH not reachable yet. Check with: virsh console ${VM_NAME}"
