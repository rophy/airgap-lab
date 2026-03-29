# airgap-lab

Air-gapped environment lab for testing container workloads without internet access.

## Overview

Simulates a corporate air-gapped environment using:
- **libvirt/QEMU** VM attached only to an isolated bridge network
- **Local Docker registry** on host (simulates corporate registry)
- **Dedicated bridge** (`airgap-br0`) — VM has no internet path by design

## Prerequisites

- libvirt, QEMU, virt-install
- cloud-image-utils (`cloud-localds`)
- Docker with compose

## Quick Start

```bash
# Set up everything (bridge, VM, registry)
./scripts/setup.sh

# SSH into the isolated VM
ssh ubuntu@10.99.0.10   # password: ubuntu

# Verify air-gap isolation (from host)
./scripts/verify.sh
```

## Configuration

Edit `config.sh` to customize:

| Variable | Default | Description |
|----------|---------|-------------|
| `VM_NAME` | `airgap-lab` | libvirt VM name |
| `BRIDGE_NAME` | `airgap-br0` | Dedicated bridge interface |
| `BRIDGE_HOST_IP` | `10.99.0.1` | Host IP on the bridge |
| `REGISTRY_PORT` | `5000` | Docker registry port |
| `VM_CPUS` | `1` | VM CPU cores |
| `VM_MEMORY` | `8192` | VM memory (MiB) |
| `VM_DISK` | `40` | VM disk (GiB) |

## Project Structure

```
airgap-lab/
├── config.sh                # Central configuration
├── docker-compose.yaml      # Local registry (port 5000)
├── images/
│   └── required.txt         # Images to pre-load
├── vm/
│   ├── cloud-init.yaml      # VM provisioning config
│   ├── network-config.yaml  # Static IP on airgap bridge
│   └── create-vm.sh         # VM creation (virt-install)
└── scripts/
    ├── setup.sh             # Full environment setup
    ├── teardown.sh          # Full environment teardown
    ├── internet.sh          # Toggle internet: open/close
    ├── verify.sh            # Verify air-gap isolation
    ├── load-images.sh       # Bulk load images to registry
    └── push-image.sh        # Push single image to registry
```

## Day-to-Day Usage

```bash
# Push a new image to the air-gapped environment (from host)
./scripts/push-image.sh myapp:v1.2.3

# Inside VM: pull it
docker pull registry.airgap:5000/myapp:v1.2.3

# Temporarily allow internet (e.g., to install packages)
sudo ./scripts/internet.sh open

# Restore air-gap
sudo ./scripts/internet.sh close
```
