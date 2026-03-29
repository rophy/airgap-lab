# Implementation Guide

## Goal

Create a local air-gapped test environment that mirrors a corporate network:
- No public internet access from the VM
- DNS resolution works (via host-side dnsmasq)
- A corporate Docker registry is the only image source
- An apt proxy allows package installation without direct internet
- Internet access can be temporarily enabled when needed

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Host Machine                                               │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐                         │
│  │ Docker       │  │ apt-cacher-ng│                         │
│  │ Registry     │  │ (apt proxy)  │                         │
│  │ :5000        │  │ :3142        │                         │
│  └──────┬───────┘  └──────┬───────┘                         │
│         │                 │                                 │
│         │  0.0.0.0 port binding (accessible on all IPs)     │
│         │                 │                                 │
│  ┌──────┴─────────────────┴──────────────────────────────┐  │
│  │ airgap-br0 (10.99.0.1/24)                             │  │
│  │ Libvirt isolated network — no NAT, no forwarding      │  │
│  │                                                       │  │
│  │ dnsmasq:                                              │  │
│  │   - forwards DNS to 8.8.8.8 / 8.8.4.4                │  │
│  │   - resolves registry.airgap → 10.99.0.1              │  │
│  │   - resolves apt-proxy.airgap → 10.99.0.1             │  │
│  │                                                       │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │ VM (10.99.0.10)                    Ubuntu 24.04 │  │  │
│  │  │                                                 │  │  │
│  │  │ - Docker (insecure-registries: registry.airgap) │  │  │
│  │  │ - apt proxy: http://apt-proxy.airgap:3142       │  │  │
│  │  │ - DNS: 10.99.0.1 (host dnsmasq)                │  │  │
│  │  │ - No internet (no NAT on bridge)                │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Design Decisions

### Why libvirt instead of multipass?

Multipass always creates a default NAT interface that provides internet access. This can't be disabled — the `--network` flag only adds additional interfaces. Root inside the VM could change routes to bypass any host-side firewall rules.

With libvirt, the VM is attached **only** to our isolated bridge. There is no internet path by design — no firewall rules needed.

### Why a libvirt network instead of a manual bridge?

A libvirt network definition (`vm/network.xml`) manages the bridge, dnsmasq, and DNS entries in one place. Benefits:
- No manual `ip link` / `iptables` commands
- dnsmasq provides DNS forwarding (VM gets DNS without internet)
- Custom hostnames (`registry.airgap`, `apt-proxy.airgap`) via dnsmasq
- No sudo needed (user in `libvirt` group)
- Clean lifecycle via `virsh net-define/start/destroy/undefine`

### Why DNS hostnames instead of IPs?

The VM references services by hostname (`registry.airgap:5000`, `apt-proxy.airgap:3142`) instead of the bridge IP. If the subnet changes, only `config.sh` and the network definition need updating — not the VM's internal config.

### Why apt-cacher-ng?

The VM can't reach the internet for `apt install`. Rather than requiring `internet.sh open` every time, apt-cacher-ng runs on the host and proxies/caches packages. The VM's apt config points to `http://apt-proxy.airgap:3142`. The host fetches packages from the internet and caches them.

### Sudo requirements

| Operation | Sudo needed? |
|---|---|
| `setup.sh` | No (user in `libvirt` group) |
| `teardown.sh` | No |
| `verify.sh` | No |
| `push-image.sh` | No |
| `internet.sh open/close` | **Yes** (iptables NAT) |

## Components

### 1. Central Configuration (`config.sh`)

All scripts source `config.sh`. Key settings:

```bash
VM_NAME=airgap-lab
BRIDGE_NAME=airgap-br0
BRIDGE_HOST_IP=10.99.0.1
BRIDGE_VM_IP=10.99.0.10
REGISTRY_PORT=5000
REGISTRY_HOSTNAME=registry.airgap
APT_CACHE_PORT=3142
APT_CACHE_HOSTNAME=apt-proxy.airgap
DNS_SERVER_1=8.8.8.8
DNS_SERVER_2=8.8.4.4
VM_CPUS=1
VM_MEMORY=8192        # MiB
VM_DISK=40            # GiB
```

All values are overridable via environment variables.

### 2. Libvirt Network (`vm/network.xml`)

Isolated network (no `<forward>` element = no NAT):

```xml
<network>
  <name>airgap-lab</name>
  <bridge name='airgap-br0'/>
  <dns>
    <forwarder addr='8.8.8.8'/>
    <forwarder addr='8.8.4.4'/>
    <host ip='10.99.0.1'>
      <hostname>registry.airgap</hostname>
      <hostname>apt-proxy.airgap</hostname>
    </host>
  </dns>
  <ip address='10.99.0.1' netmask='255.255.255.0'/>
</network>
```

- **No `<forward>`** → libvirt creates no NAT/masquerade rules
- **`<dns><forwarder>`** → dnsmasq forwards DNS queries to Google DNS (dnsmasq runs on the host, so it has internet)
- **`<host>`** → custom hostname resolution for services

### 3. Host Services (`docker-compose.yaml`)

Two containers on the host:

- **registry:2** on port 5000 — Docker image registry
- **apt-cacher-ng** on port 3142 — apt package proxy/cache

Both bind to `0.0.0.0`, making them accessible on the bridge IP (`10.99.0.1`). Persistent volumes preserve data across restarts.

### 4. VM Provisioning

**`vm/cloud-init.yaml`** — cloud-init user-data template:
- Installs docker.io, curl, jq
- Configures Docker's `insecure-registries` for `registry.airgap`
- Configures apt proxy pointing to `apt-proxy.airgap:3142`
- Creates `ubuntu` user with password + SSH key

**`vm/network-config.yaml`** — static IP configuration:
- IP: `10.99.0.10/24`
- Gateway: `10.99.0.1`
- DNS: `10.99.0.1` (host dnsmasq)

**`vm/create-vm.sh`** — VM creation:
1. Copies Ubuntu cloud image to `vm/disks/`
2. Resizes disk to configured size
3. Renders cloud-init templates (substitutes config values)
4. Generates seed ISO via `cloud-localds`
5. Injects host user's SSH public key
6. Runs `virt-install` with the isolated network
7. Waits for SSH to become available

### 5. Internet Toggle (`scripts/internet.sh`)

The only operation requiring sudo. Toggles NAT for the bridge subnet:

- **`open`** — enables ip_forward, adds MASQUERADE and FORWARD rules
- **`close`** — removes those rules

When open, the VM can reach the internet. When closed (default), only DNS and host services are reachable.

### 6. Image Management

- **`scripts/load-images.sh`** — reads `images/required.txt`, pulls each image, retags as `localhost:5000/<image>`, pushes to registry
- **`scripts/push-image.sh`** — same flow for a single image passed as argument

Both run on the host and push to `localhost:5000`.

## Project Structure

```
airgap-lab/
├── config.sh                   # Central configuration
├── docker-compose.yaml         # Registry + apt-cache services
├── .gitignore
├── images/
│   └── required.txt            # Images to pre-load (one per line)
├── vm/
│   ├── cloud-init.yaml         # Cloud-init user-data template
│   ├── network-config.yaml     # VM static IP config template
│   ├── network.xml             # Libvirt network definition template
│   ├── create-vm.sh            # VM creation script (virt-install)
│   ├── cache/                  # Downloaded cloud images (gitignored)
│   └── disks/                  # VM disk images (gitignored)
└── scripts/
    ├── setup.sh                # Full environment setup
    ├── teardown.sh             # Full environment teardown
    ├── internet.sh             # Toggle internet access (sudo)
    ├── verify.sh               # Verify air-gap isolation
    ├── load-images.sh          # Bulk load images to registry
    └── push-image.sh           # Push single image to registry
```

## Workflow

### Setup

```bash
./scripts/setup.sh
```

Steps:
1. Downloads Ubuntu 24.04 cloud image (cached in `vm/cache/`)
2. Creates libvirt network `airgap-lab` (bridge `airgap-br0`)
3. Creates VM with `virt-install` (only attached to `airgap-br0`)
4. Starts registry + apt-cache via `docker compose`
5. Loads images from `images/required.txt` into registry

### Verify

```bash
./scripts/verify.sh
```

Checks:
- Internet access is blocked (curl to google.com fails)
- DNS resolution works (nslookup google.com succeeds)
- `registry.airgap` resolves to bridge IP
- Registry API is accessible

### Day-to-day

```bash
# Push image to registry (from host)
./scripts/push-image.sh myapp:v1.2.3

# SSH into the VM
ssh ubuntu@10.99.0.10

# Inside VM: pull from registry
docker pull registry.airgap:5000/myapp:v1.2.3

# Inside VM: install packages (via apt proxy)
sudo apt-get install -y vim

# Temporarily allow internet (from host)
sudo ./scripts/internet.sh open
# ... do work ...
sudo ./scripts/internet.sh close
```

### Teardown

```bash
./scripts/teardown.sh
```

Removes VM, network, and stops services. Optionally removes data volumes.

## Prerequisites

- **libvirt** + **QEMU** + **virt-install** — VM management
- **cloud-image-utils** (`cloud-localds`) — cloud-init seed ISO generation
- **Docker** with compose — registry and apt-cache
- User must be in the `libvirt` group (`sudo usermod -aG libvirt $USER`)
