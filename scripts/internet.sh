#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

usage() {
  echo "Usage: sudo $0 <open|close>"
  echo "  open   - temporarily allow internet access (add NAT for bridge)"
  echo "  close  - restore air-gap isolation (remove NAT for bridge)"
  exit 1
}

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run with sudo"
  exit 1
fi

ACTION="${1:-}"
[[ -z "${ACTION}" ]] && usage

# Detect outbound interface
OUT_IFACE=$(ip route | awk '/default/ {print $5; exit}')

case "${ACTION}" in
  open)
    # Enable forwarding and NAT for the bridge subnet
    sysctl -w net.ipv4.ip_forward=1 > /dev/null
    iptables -t nat -A POSTROUTING -s "${BRIDGE_SUBNET}" -o "${OUT_IFACE}" -j MASQUERADE
    iptables -A FORWARD -i "${BRIDGE_NAME}" -o "${OUT_IFACE}" -j ACCEPT
    iptables -A FORWARD -i "${OUT_IFACE}" -o "${BRIDGE_NAME}" -m state --state ESTABLISHED,RELATED -j ACCEPT
    echo "Internet access opened for ${BRIDGE_SUBNET} via ${OUT_IFACE}."
    ;;
  close)
    # Remove NAT and forwarding rules
    iptables -t nat -D POSTROUTING -s "${BRIDGE_SUBNET}" -o "${OUT_IFACE}" -j MASQUERADE 2>/dev/null || true
    iptables -D FORWARD -i "${BRIDGE_NAME}" -o "${OUT_IFACE}" -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -i "${OUT_IFACE}" -o "${BRIDGE_NAME}" -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
    echo "Air-gap restored. NAT removed for ${BRIDGE_SUBNET}."
    ;;
  *)
    usage
    ;;
esac
