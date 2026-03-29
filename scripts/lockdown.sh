#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (use sudo)"
  exit 1
fi

HOST_IP=$(ip route | grep default | awk '{print $3}')
REGISTRY_PORT=5000

echo "Applying air-gap firewall rules..."
echo "  Host/registry: ${HOST_IP}:${REGISTRY_PORT}"

# Flush existing OUTPUT rules
iptables -F OUTPUT

# Allow loopback
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established/related connections
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow DNS (UDP and TCP)
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Allow access to host registry
iptables -A OUTPUT -d "${HOST_IP}" -p tcp --dport "${REGISTRY_PORT}" -j ACCEPT

# Allow multipass communication
iptables -A OUTPUT -d "${HOST_IP}" -p tcp --dport 22 -j ACCEPT

# Drop everything else
iptables -A OUTPUT -j DROP

echo "Air-gap lockdown applied. Only registry and DNS traffic allowed."
