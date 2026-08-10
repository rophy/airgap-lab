# Air-Gap Lab Configuration
# Sourced by all scripts

VM_NAME="${VM_NAME:-airgap-lab}"

# Libvirt network (isolated mode — no NAT, DNS via dnsmasq on host)
NETWORK_NAME="${NETWORK_NAME:-${VM_NAME}}"
BRIDGE_NAME="${BRIDGE_NAME:-airgap-br0}"
BRIDGE_SUBNET="${BRIDGE_SUBNET:-10.99.0.0/24}"
BRIDGE_HOST_IP="${BRIDGE_HOST_IP:-10.99.0.1}"
BRIDGE_VM_IP="${BRIDGE_VM_IP:-10.99.0.10}"

# DNS forwarders (used by libvirt's dnsmasq)
DNS_SERVER_1="${DNS_SERVER_1:-8.8.8.8}"
DNS_SERVER_2="${DNS_SERVER_2:-8.8.4.4}"

# Registry (runs on host, accessible via hostname from VM)
REGISTRY_PORT="${REGISTRY_PORT:-5000}"
REGISTRY_HOSTNAME="${REGISTRY_HOSTNAME:-registry.airgap}"

# Apt cache proxy
APT_CACHE_PORT="${APT_CACHE_PORT:-3142}"
APT_CACHE_HOSTNAME="${APT_CACHE_HOSTNAME:-apt-proxy.airgap}"

# VM resources
VM_CPUS="${VM_CPUS:-1}"
VM_MEMORY="${VM_MEMORY:-8192}"  # in MiB for virt-install
VM_DISK="${VM_DISK:-40}"        # in GiB for virt-install

# AI Gateway (reverse proxy for LLM API access from VM)
AI_GATEWAY_HOSTNAME="${AI_GATEWAY_HOSTNAME:-ai-gateway.airgap}"
AI_GATEWAY_PORT="${AI_GATEWAY_PORT:-8090}"
LLM_API_BASE_URL="${LLM_API_BASE_URL:-https://generativelanguage.googleapis.com/v1beta/openai}"
LLM_API_KEY_FILE="${LLM_API_KEY_FILE:-${HOME}/.airgap-lab/api-key}"

# Ubuntu cloud image
VM_IMAGE_URL="${VM_IMAGE_URL:-https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img}"
# Resolve project root from config.sh location
_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_IMAGE_CACHE="${VM_IMAGE_CACHE:-${_CONFIG_DIR}/vm/cache}"
VM_LIBVIRT_DIR="${VM_LIBVIRT_DIR:-${_CONFIG_DIR}/vm/disks}"
