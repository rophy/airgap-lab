# Air-Gap Lab

## kubectl Context

No host-side kubectl context. To run commands inside the VM:
```bash
ssh ubuntu@10.99.0.10 kubectl ...
```

## Running Commands in the VM

```bash
ssh -o StrictHostKeyChecking=no -o BatchMode=yes ubuntu@10.99.0.10 "<command>"
```

VM IP is `BRIDGE_VM_IP` from `config.sh` (default `10.99.0.10`).

## Sudo

Only `scripts/internet.sh` requires sudo. All other scripts run unprivileged (user must be in `libvirt` group).

## Templates

Files in `vm/` use placeholder tokens (e.g., `BRIDGE_HOST_IP`, `REGISTRY_HOSTNAME`) that are substituted by `create-vm.sh` and `setup.sh` at runtime via `sed`.
