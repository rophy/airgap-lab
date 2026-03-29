# airgap-lab

Air-gapped environment lab for testing container workloads without internet access.

## Overview

Simulates a corporate air-gapped environment using:
- **Multipass** Ubuntu VM with network isolation (iptables egress blocking)
- **Local Docker registry** on host (simulates corporate registry)

## Quick Start

```bash
# Set up everything (registry, VM, firewall)
./scripts/setup.sh

# SSH into the isolated VM
multipass shell airgap-lab

# Verify air-gap isolation (inside VM)
sudo ./scripts/verify.sh
```

## Project Structure

```
airgap-lab/
├── docker-compose.yaml      # Local registry (port 5000)
├── images/
│   └── required.txt         # Images to pre-load
├── vm/
│   ├── cloud-init.yaml      # VM provisioning config
│   └── create-vm.sh         # VM creation script
└── scripts/
    ├── setup.sh             # Full environment setup
    ├── teardown.sh          # Full environment teardown
    ├── lockdown.sh          # Apply firewall rules in VM
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
docker pull <HOST_IP>:5000/myapp:v1.2.3

# Temporarily disable air-gap (inside VM)
sudo ./scripts/unlock.sh

# Re-enable air-gap
sudo ./scripts/lockdown.sh
```
