# Air-Gap Lab Configuration
# Sourced by all scripts

VM_NAME="${VM_NAME:-airgap-lab}"

# Dedicated bridge network (no NAT — VM can only reach host on this network)
BRIDGE_NAME="${BRIDGE_NAME:-airgap-br0}"
BRIDGE_SUBNET="${BRIDGE_SUBNET:-10.99.0.0/24}"
BRIDGE_HOST_IP="${BRIDGE_HOST_IP:-10.99.0.1}"
BRIDGE_VM_IP="${BRIDGE_VM_IP:-10.99.0.10}"

# Registry (runs on host, accessible via bridge IP)
REGISTRY_PORT="${REGISTRY_PORT:-5000}"

# VM resources
VM_CPUS="${VM_CPUS:-1}"
VM_MEMORY="${VM_MEMORY:-8192}"  # in MiB for virt-install
VM_DISK="${VM_DISK:-40}"        # in GiB for virt-install

# Ubuntu cloud image
VM_IMAGE_URL="${VM_IMAGE_URL:-https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img}"
VM_IMAGE_CACHE="${VM_IMAGE_CACHE:-${SCRIPT_DIR:-.}/vm/cache}"
VM_LIBVIRT_DIR="${VM_LIBVIRT_DIR:-/var/lib/libvirt/images}"
