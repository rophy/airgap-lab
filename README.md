# airgap-lab

Air-gapped environment lab for testing container workloads without internet access.

## Overview

Simulates a corporate air-gapped environment using:
- **Multipass** Ubuntu VM with network isolation
- **Local Docker registry** on host (simulates corporate registry)
- **Dedicated bridge network** (`airgap-br0`) with host-side firewall enforcement

## Quick Start

```bash
# Set up everything (bridge, registry, VM, firewall)
./scripts/setup.sh

# SSH into the isolated VM
multipass shell airgap-lab

# Verify air-gap isolation (from host)
./scripts/verify.sh
```

## Configuration

Edit `config.sh` to customize:

| Variable | Default | Description |
|----------|---------|-------------|
| `VM_NAME` | `airgap-lab` | Multipass VM name |
| `BRIDGE_NAME` | `airgap-br0` | Dedicated bridge interface |
| `BRIDGE_HOST_IP` | `10.99.0.1` | Host IP on the bridge |
| `REGISTRY_PORT` | `5000` | Docker registry port |
| `VM_CPUS` | `1` | VM CPU cores |
| `VM_MEMORY` | `8G` | VM memory |
| `VM_DISK` | `40G` | VM disk size |

## Project Structure

```
airgap-lab/
├── config.sh                # Central configuration
├── docker-compose.yaml      # Local registry (port 5000)
├── images/
│   └── required.txt         # Images to pre-load
├── vm/
│   ├── cloud-init.yaml      # VM provisioning config
│   └── create-vm.sh         # VM creation script
└── scripts/
    ├── setup.sh             # Full environment setup
    ├── teardown.sh          # Full environment teardown
    ├── lockdown.sh          # Apply host-side firewall rules
    ├── unlock.sh            # Remove firewall rules
    ├── verify.sh            # Verify air-gap isolation
    ├── load-images.sh       # Bulk load images to registry
    └── push-image.sh        # Push single image to registry
```

## Day-to-Day Usage

```bash
# Push a new image to the air-gapped environment (from host)
./scripts/push-image.sh myapp:v1.2.3

# Inside VM: pull it
docker pull 10.99.0.1:5000/myapp:v1.2.3

# Temporarily disable air-gap (from host)
sudo ./scripts/unlock.sh

# Re-enable air-gap
sudo ./scripts/lockdown.sh
```
