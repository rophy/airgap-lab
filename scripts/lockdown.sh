#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (use sudo)"
  exit 1
fi

# Get VM's IP on the default multipass bridge
VM_DEFAULT_IP=$(multipass info "${VM_NAME}" --format json | jq -r '.info["'"${VM_NAME}"'"].ipv4[0]')

if [[ -z "${VM_DEFAULT_IP}" || "${VM_DEFAULT_IP}" == "null" ]]; then
  echo "Error: could not determine VM IP for '${VM_NAME}'"
  exit 1
fi

CHAIN_NAME="AIRGAP-${VM_NAME}"

echo "Applying air-gap firewall rules on host..."
echo "  VM default IP: ${VM_DEFAULT_IP}"
echo "  Chain: ${CHAIN_NAME}"

# Clean up existing chain if present
iptables -D FORWARD -s "${VM_DEFAULT_IP}" -j "${CHAIN_NAME}" 2>/dev/null || true
iptables -F "${CHAIN_NAME}" 2>/dev/null || true
iptables -X "${CHAIN_NAME}" 2>/dev/null || true

# Create dedicated chain
iptables -N "${CHAIN_NAME}"

# Allow established/related
iptables -A "${CHAIN_NAME}" -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow DNS
iptables -A "${CHAIN_NAME}" -p udp --dport 53 -j ACCEPT
iptables -A "${CHAIN_NAME}" -p tcp --dport 53 -j ACCEPT

# Allow traffic to the bridge host IP (registry)
iptables -A "${CHAIN_NAME}" -d "${BRIDGE_HOST_IP}" -j ACCEPT

# Drop everything else
iptables -A "${CHAIN_NAME}" -j DROP

# Jump to our chain for VM traffic
iptables -I FORWARD -s "${VM_DEFAULT_IP}" -j "${CHAIN_NAME}"

echo "Air-gap lockdown applied."
