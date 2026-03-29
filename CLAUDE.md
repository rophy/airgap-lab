# Air-Gap Lab

Local air-gapped test environment using Multipass VM + local Docker registry.

## Stack

- **Multipass** for VM provisioning
- **Docker registry:2** on host port 5000
- **iptables** for network isolation inside VM

## Key Commands

```bash
# Full setup (host, with internet)
./scripts/setup.sh

# Teardown everything
./scripts/teardown.sh

# Push a single image to local registry
./scripts/push-image.sh nginx:1.25

# Inside VM: verify air-gap
sudo ./scripts/verify.sh
```
