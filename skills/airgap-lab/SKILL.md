---
name: airgap-lab
description: Use when you need to test container images or workloads in an air-gapped environment without internet access. Triggers on "air-gap", "offline", "no internet", "isolated environment".
---

# Air-Gap Lab Usage

Air-gapped VM (libvirt) with no internet access, a Docker registry, and an AI gateway. All commands run from `~/projects/airgap-lab`.

## Status and Access

```bash
make status    # Show services (registry, apt-cache, ai-gateway) and VM state
make ssh       # SSH into the VM
```

## Pushing Images

Push from the host so the VM can pull them:

```bash
./scripts/push-image.sh nginx:1.25
# → localhost:5000/nginx:1.25

./scripts/push-image.sh quay.io/cilium/cilium:v1.13.10
# → localhost:5000/quay.io/cilium/cilium:v1.13.10

# Multi-arch images that fail docker push
skopeo copy --override-arch amd64 --override-os linux \
  docker://docker.io/hashicorp/vault:2.0.3 \
  docker://localhost:5000/hashicorp/vault:2.0.3 \
  --dest-tls-verify=false
```

## Pulling Images (inside the VM)

```bash
docker pull registry.airgap:5000/nginx:1.25
```

## Inspecting the Registry

```bash
curl -s http://localhost:5000/v2/_catalog
curl -s http://localhost:5000/v2/nginx/tags/list
```

## Running opencode (inside the VM)

```bash
make ssh
opencode
```

opencode is pre-configured to use the AI gateway. No API key needed inside the VM.

## Setup and Teardown

```bash
make setup     # Create VM, start services, provision everything
make teardown  # Remove VM, network, stop services
make verify    # Verify air-gap isolation
```

For configuration, prerequisites, and troubleshooting, see `~/projects/airgap-lab/README.md`.
