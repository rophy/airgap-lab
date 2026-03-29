#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (use sudo)"
  exit 1
fi

iptables -F OUTPUT
iptables -A OUTPUT -j ACCEPT

echo "Firewall rules cleared. Full internet access restored."
