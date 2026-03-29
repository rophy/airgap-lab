# Air-Gap Lab

Local air-gapped test environment using libvirt VM + local Docker registry.

## Stack

- **libvirt/QEMU** for VM provisioning (Ubuntu 24.04 cloud image)
- **Docker registry:2** on host port 5000
- **airgap-br0** bridge (10.99.0.0/24) — VM's only network interface
- VM has no internet by design; `internet.sh open` adds NAT temporarily

## Key Commands

```bash
./scripts/setup.sh              # Full setup (bridge, VM, registry)
./scripts/teardown.sh           # Full teardown
./scripts/push-image.sh IMG     # Push image to local registry
./scripts/verify.sh             # Verify air-gap from host
sudo ./scripts/internet.sh open  # Temporarily allow internet
sudo ./scripts/internet.sh close # Restore air-gap
```

## VM Access

```bash
ssh ubuntu@10.99.0.10           # password: ubuntu
virsh console airgap-lab        # serial console
```
