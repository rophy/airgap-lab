# Air-Gap Lab

Local air-gapped test environment using Multipass VM + local Docker registry + dedicated bridge network.

## Stack

- **Multipass** for VM provisioning (Ubuntu 24.04)
- **Docker registry:2** on host port 5000
- **airgap-br0** bridge (10.99.0.0/24) for VM-to-registry communication
- **Host-side iptables** FORWARD rules for network isolation

## Configuration

All settings in `config.sh`, sourced by every script.

## Key Commands

```bash
./scripts/setup.sh           # Full setup (bridge, registry, VM, firewall)
./scripts/teardown.sh        # Full teardown
./scripts/push-image.sh IMG  # Push image to local registry
./scripts/verify.sh          # Verify air-gap from host
sudo ./scripts/lockdown.sh   # Apply firewall rules
sudo ./scripts/unlock.sh     # Remove firewall rules
```
