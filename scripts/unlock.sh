#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (use sudo)"
  exit 1
fi

VM_DEFAULT_IP=$(multipass info "${VM_NAME}" --format json | jq -r '.info["'"${VM_NAME}"'"].ipv4[0]')
CHAIN_NAME="AIRGAP-${VM_NAME}"

# Remove jump rule and chain
iptables -D FORWARD -s "${VM_DEFAULT_IP}" -j "${CHAIN_NAME}" 2>/dev/null || true
iptables -F "${CHAIN_NAME}" 2>/dev/null || true
iptables -X "${CHAIN_NAME}" 2>/dev/null || true

echo "Firewall rules removed. VM has full internet access."
