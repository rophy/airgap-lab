#!/usr/bin/env bash
#
# Provisions the air-gapped VM over SSH.
# Run from the host after the VM is booted and SSH-reachable.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o LogLevel=ERROR"
SSH_CMD="ssh ${SSH_OPTS} ubuntu@${BRIDGE_VM_IP}"

echo "Provisioning VM at ${BRIDGE_VM_IP}..."

# Wait for cloud-init to finish (user creation, SSH keys)
echo "  Waiting for cloud-init to finish..."
${SSH_CMD} "cloud-init status --wait" >/dev/null 2>&1

# Configure apt proxy
echo "  Configuring apt proxy..."
${SSH_CMD} "sudo tee /etc/apt/apt.conf.d/90proxy >/dev/null" <<EOF
Acquire::http::Proxy "http://${APT_CACHE_HOSTNAME}:${APT_CACHE_PORT}";
Acquire::https::Proxy "http://${APT_CACHE_HOSTNAME}:${APT_CACHE_PORT}";
EOF

# Install packages
echo "  Installing packages..."
${SSH_CMD} "sudo apt-get update -qq && sudo apt-get install -y -qq docker.io curl jq" >/dev/null 2>&1

# Configure Docker
echo "  Configuring Docker..."
${SSH_CMD} "sudo tee /etc/docker/daemon.json >/dev/null" <<EOF
{
  "insecure-registries": ["${REGISTRY_HOSTNAME}:${REGISTRY_PORT}"]
}
EOF
${SSH_CMD} "sudo systemctl enable docker && sudo systemctl restart docker && sudo usermod -aG docker ubuntu"

# Set up opencode environment
echo "  Setting up opencode environment..."
${SSH_CMD} "sudo tee /etc/profile.d/opencode.sh >/dev/null" <<EOF
export OPENAI_API_BASE=http://${AI_GATEWAY_HOSTNAME}:${AI_GATEWAY_PORT}/v1
export OPENAI_API_KEY=dummy
EOF

# Install opencode binary
OPENCODE_BIN="$(which opencode 2>/dev/null || echo "${HOME}/.opencode/bin/opencode")"
if [[ -f "${OPENCODE_BIN}" ]]; then
  echo "  Installing opencode binary..."
  ${SSH_CMD} "rm -rf /tmp/opencode.bin"
  scp ${SSH_OPTS} "${OPENCODE_BIN}" "ubuntu@${BRIDGE_VM_IP}:/tmp/opencode.bin"
  ${SSH_CMD} "sudo mv /tmp/opencode.bin /usr/local/bin/opencode && sudo chmod +x /usr/local/bin/opencode"
else
  echo "  Skipping opencode install (binary not found on host)."
fi

# Configure opencode to use the AI gateway via custom provider
# Uses "custom" provider (not "openai") so opencode sends chat/completions
# instead of the Responses API, which Gemini doesn't support
echo "  Configuring opencode..."
${SSH_CMD} "mkdir -p ~/.config/opencode"
${SSH_CMD} "cat > ~/.config/opencode/opencode.jsonc" <<OCEOF
{
  "\$schema": "https://opencode.ai/config.json",
  "provider": {
    "custom": {
      "api": "http://${AI_GATEWAY_HOSTNAME}:${AI_GATEWAY_PORT}/v1",
      "models": {
        "gemini-2.5-flash": {
          "name": "Gemini 2.5 Flash"
        }
      }
    }
  },
  "model": "custom/gemini-2.5-flash"
}
OCEOF

echo "  VM provisioned."
