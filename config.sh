# Air-Gap Lab Configuration
# Sourced by all scripts

VM_NAME="${VM_NAME:-airgap-lab}"

# Dedicated bridge network (no NAT — VM can only reach host on this network)
BRIDGE_NAME="${BRIDGE_NAME:-airgap-br0}"
BRIDGE_SUBNET="${BRIDGE_SUBNET:-10.99.0.0/24}"
BRIDGE_HOST_IP="${BRIDGE_HOST_IP:-10.99.0.1}"

# Registry (runs on host, accessible via bridge IP)
REGISTRY_PORT="${REGISTRY_PORT:-5000}"

# VM resources
VM_CPUS="${VM_CPUS:-1}"
VM_MEMORY="${VM_MEMORY:-8G}"
VM_DISK="${VM_DISK:-40G}"
