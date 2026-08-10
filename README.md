# airgap-lab

Air-gapped environment lab for testing container workloads without internet access.

## Overview

Simulates a corporate air-gapped network using:
- **libvirt VM** attached only to an isolated bridge — no internet path by design
- **Docker registry** on host (HTTP, port 5000) — simulates a corporate container registry
- **apt-cacher-ng** on host — proxies/caches apt packages for the VM
- **DNS via dnsmasq** — resolves `registry.airgap` and `apt-proxy.airgap` to the host

No sudo required for setup or teardown (user must be in `libvirt` group).

## Prerequisites

```bash
# Required packages
sudo apt install qemu-kvm libvirt-daemon-system virtinst cloud-image-utils

# Add yourself to the libvirt group (re-login after)
sudo usermod -aG libvirt $USER

# Docker with compose plugin

# Optional: for pushing multi-arch images that fail with docker push
sudo apt install skopeo
```

## Quick Start

All commands should be run from the repository root (`~/projects/airgap-lab`).

```bash
make setup     # Set up everything (network, VM, registry, apt cache)
make status    # Check services and VM state
make verify    # Verify air-gap isolation
make ssh       # SSH into the VM
make teardown  # Remove everything
```

## What Works Inside the VM

```bash
# DNS resolves (via host dnsmasq)
nslookup google.com         # works
curl https://google.com     # blocked (no internet)

# Docker registry
docker pull registry.airgap:5000/myapp:v1.2.3

# apt packages (via apt-cacher-ng proxy)
sudo apt-get update && sudo apt-get install -y vim
```

## Inspecting the Registry

The registry exposes the [Docker Registry HTTP API V2](https://distribution.github.io/distribution/spec/api/):

```bash
# List all repositories
curl -s http://localhost:5000/v2/_catalog

# List tags for a specific image
curl -s http://localhost:5000/v2/nginx/tags/list

# For images with nested paths
curl -s http://localhost:5000/v2/quay.io/cilium/cilium/tags/list
```

## Pushing Images to the Registry

From the host (which has internet access):

```bash
# Single image (pulls from upstream if not already local, then pushes to the registry)
./scripts/push-image.sh nginx:1.25
# → localhost:5000/nginx:1.25

# Full registry paths are preserved
./scripts/push-image.sh quay.io/cilium/cilium:v1.13.10
# → localhost:5000/quay.io/cilium/cilium:v1.13.10

# Bulk from a list
echo "nginx:1.25" >> images/required.txt
echo "redis:7" >> images/required.txt
./scripts/load-images.sh
```

Pushing an image that already exists in the registry overwrites the tag.

### Multi-arch manifest push failures

Some images (notably HashiCorp) fail `docker push` with "does not provide any platform". Use `skopeo` instead:

```bash
skopeo copy --override-arch amd64 --override-os linux \
  docker://docker.io/hashicorp/vault:2.0.3 \
  docker://localhost:5000/hashicorp/vault:2.0.3 \
  --dest-tls-verify=false
```

Inside the VM:

```bash
docker pull registry.airgap:5000/nginx:1.25
```

## Temporarily Allowing Internet

```bash
# Open (adds NAT — only operation requiring sudo)
sudo ./scripts/internet.sh open

# Close (removes NAT, restores air-gap)
sudo ./scripts/internet.sh close
```

## AI Gateway (LLM API Proxy)

The lab includes an AI gateway that proxies LLM API requests from the VM to an upstream provider. The gateway injects the API key so the VM never sees it.

### Setup

1. Create an API key file on the host:

```bash
mkdir -p ~/.airgap-lab
echo "your-api-key" > ~/.airgap-lab/api-key
chmod 600 ~/.airgap-lab/api-key
```

2. Optionally configure the upstream in `config.sh`:

```bash
LLM_API_BASE_URL="https://generativelanguage.googleapis.com/v1beta/openai"  # default (Gemini)
```

3. Run `./scripts/setup.sh` — the gateway starts automatically.

### Using opencode in the VM

```bash
ssh ubuntu@10.99.0.10
opencode
```

opencode is pre-configured to use the gateway. The API key is injected by the gateway — no key configuration needed inside the VM.

### Customizing the whitelist

Edit `config/egress-whitelist.txt` to add or remove allowed upstream domains (one per line). Restart the gateway:

```bash
docker compose restart ai-gateway
```

## Configuration

Edit `config.sh` to customize. All values are overridable via environment variables.

| Variable | Default | Description |
|---|---|---|
| `VM_NAME` | `airgap-lab` | libvirt VM name |
| `BRIDGE_NAME` | `airgap-br0` | Bridge interface |
| `BRIDGE_HOST_IP` | `10.99.0.1` | Host IP on bridge |
| `BRIDGE_VM_IP` | `10.99.0.10` | VM IP on bridge |
| `REGISTRY_PORT` | `5000` | Docker registry port |
| `REGISTRY_HOSTNAME` | `registry.airgap` | Registry hostname |
| `APT_CACHE_PORT` | `3142` | apt-cacher-ng port |
| `APT_CACHE_HOSTNAME` | `apt-proxy.airgap` | apt proxy hostname |
| `VM_CPUS` | `1` | VM CPU cores |
| `VM_MEMORY` | `8192` | VM memory (MiB) |
| `VM_DISK` | `40` | VM disk (GiB) |
| `AI_GATEWAY_HOSTNAME` | `ai-gateway.airgap` | AI gateway hostname |
| `AI_GATEWAY_PORT` | `8090` | AI gateway port |
| `LLM_API_BASE_URL` | `https://generativelanguage.googleapis.com/v1beta/openai` | Upstream LLM API URL |
| `LLM_API_KEY_FILE` | `~/.airgap-lab/api-key` | Path to API key file |

## Teardown

```bash
./scripts/teardown.sh
```

Removes VM, libvirt network, and stops services. Prompts to remove data volumes.

## Project Structure

```
airgap-lab/
├── Makefile                    # Common commands (status, setup, ssh, etc.)
├── config.sh                   # Central configuration
├── docker-compose.yaml         # Registry + apt-cache
├── images/
│   └── required.txt            # Images to pre-load
├── vm/
│   ├── cloud-init.yaml         # VM provisioning template
│   ├── network-config.yaml     # VM static IP template
│   ├── network.xml             # Libvirt network template
│   └── create-vm.sh            # VM creation (virt-install)
└── scripts/
    ├── setup.sh                # Full setup
    ├── teardown.sh             # Full teardown
    ├── internet.sh             # Toggle internet (sudo)
    ├── verify.sh               # Verify air-gap
    ├── load-images.sh          # Bulk image push
    └── push-image.sh           # Single image push
```

## Troubleshooting

### "http: server gave HTTP response to HTTPS client"

The registry runs plain HTTP. If you see this error when pushing from the host, add `localhost:5000` to Docker's insecure registries:

```json
// /etc/docker/daemon.json
{
  "insecure-registries": ["localhost:5000"]
}
```

Then restart Docker: `sudo systemctl restart docker`.

The VM's Docker daemon is already configured for `registry.airgap:5000` by `setup.sh`.

See [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) for architecture details and design decisions.
