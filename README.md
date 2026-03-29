# airgap-lab

Air-gapped environment lab for testing container workloads without internet access.

## Overview

Simulates a corporate air-gapped environment using:
- **Multipass** Ubuntu VM with network isolation (iptables egress blocking)
- **Local Docker registry** on host (simulates corporate registry)
- **kind/minikube** inside the VM for Kubernetes testing

## Components

- `registry/` - Local Docker registry setup
- `vm/` - Multipass VM provisioning and cloud-init
- `scripts/` - Helper scripts for image loading, setup, teardown
