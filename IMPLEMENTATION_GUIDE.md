# Implementation Guide

## Goal

Create a local air-gapped test environment that mirrors a corporate network:
- No public internet access
- Internal DNS works
- A corporate Docker registry is the only image source
- Kubernetes (kind/minikube) runs inside the isolated VM

## Architecture

```
┌─────────────────────────────────────────────────┐
│  Host Machine                                   │
│                                                 │
│  ┌──────────────┐                               │
│  │ Docker       │                               │
│  │ Registry     │  :5000                        │
│  │ (corporate   │◄─────────────────────┐        │
│  │  simulator)  │                      │        │
│  └──────────────┘                      │        │
│                                        │        │
│  ┌─────────────────────────────────────┼──────┐ │
│  │ Multipass VM (Ubuntu)               │      │ │
│  │                                     │      │ │
│  │  iptables: deny all egress          │      │ │
│  │  except:                            │      │ │
│  │    - host registry (IP:5000)        │      │ │
│  │    - DNS (53/udp, 53/tcp)           │      │ │
│  │                                     │      │ │
│  │  ┌───────────┐  ┌────────────────┐  │      │ │
│  │  │  Docker   │  │ kind/minikube  │  │      │ │
│  │  │  (pulls   │  │ (uses registry │  │      │ │
│  │  │  from     │  │  mirror)       │  │      │ │
│  │  │  registry)│  │                │  │      │ │
│  │  └───────────┘  └────────────────┘  │      │ │
│  └─────────────────────────────────────┴──────┘ │
└─────────────────────────────────────────────────┘
```

## Components to Build

### 1. Local Docker Registry (Host)

**Directory:** `registry/`

- `docker-compose.yml` to run a registry:2 container on port 5000
- Persistent volume for image storage
- Optional: basic auth or TLS (skip for simplicity initially)
- Script to pre-load images: pull from Docker Hub, retag, push to local registry

**Example image list to pre-load:**
- `kindest/node:<version>` (for kind)
- `registry.k8s.io/pause:3.9`
- `registry.k8s.io/coredns/coredns:v1.11.1`
- `registry.k8s.io/etcd:3.5.12-0`
- `registry.k8s.io/kube-apiserver:<version>`
- `registry.k8s.io/kube-controller-manager:<version>`
- `registry.k8s.io/kube-scheduler:<version>`
- `registry.k8s.io/kube-proxy:<version>`
- Any application images needed for testing

**Script:** `scripts/load-images.sh`
- Takes an image list file as input
- Pulls each image from upstream
- Retags as `<host-ip>:5000/<image>`
- Pushes to local registry

### 2. Multipass VM Provisioning

**Directory:** `vm/`

- `cloud-init.yaml` - cloud-init config for the VM
- `create-vm.sh` - wrapper script to launch the VM

**VM specs (configurable):**
- 4 CPU, 8GB RAM, 40GB disk (adjust as needed)
- Ubuntu 22.04 or 24.04

**cloud-init should install:**
- docker.io / containerd
- kind
- kubectl
- helm (if needed)
- Any other CLI tools

**cloud-init should configure:**
- Docker daemon to use the host registry as mirror (`/etc/docker/daemon.json`)
- containerd registry mirror config
- Mark the host registry as insecure (HTTP, no TLS)

### 3. Network Isolation (Firewall)

**Script:** `scripts/lockdown.sh` (runs inside the VM)

iptables rules to apply inside the VM:

```bash
# Get host/gateway IP (multipass bridge)
HOST_IP=$(ip route | grep default | awk '{print $3}')
REGISTRY_PORT=5000

# Flush existing rules
iptables -F OUTPUT

# Allow loopback
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established/related connections
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow DNS (UDP and TCP)
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Allow access to host registry
iptables -A OUTPUT -d $HOST_IP -p tcp --dport $REGISTRY_PORT -j ACCEPT

# Allow multipass communication (needed for VM management)
iptables -A OUTPUT -d $HOST_IP -p tcp --dport 22 -j ACCEPT

# Drop everything else
iptables -A OUTPUT -j DROP
```

**Script:** `scripts/unlock.sh` (runs inside the VM, for temporarily disabling isolation)

```bash
iptables -F OUTPUT
iptables -A OUTPUT -j ACCEPT
```

### 4. Kind Cluster Configuration

**File:** `kind/kind-config.yaml`

Kind needs special config to work in air-gapped mode:
- Use the pre-loaded `kindest/node` image from the local registry
- Configure containerd inside kind nodes to mirror all registries to the local registry

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
containerdConfigPatches:
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
      endpoint = ["http://<HOST_IP>:5000"]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."registry.k8s.io"]
      endpoint = ["http://<HOST_IP>:5000"]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."<HOST_IP>:5000"]
      endpoint = ["http://<HOST_IP>:5000"]
```

Kind node image must be pre-loaded into the VM's docker before creating the cluster:
```bash
docker pull <HOST_IP>:5000/kindest/node:<version>
docker tag <HOST_IP>:5000/kindest/node:<version> kindest/node:<version>
kind create cluster --image kindest/node:<version> --config kind-config.yaml
```

### 5. Helper Scripts

**`scripts/setup.sh`** - Full setup orchestrator:
1. Start the local registry on host
2. Load required images into registry
3. Create multipass VM
4. Wait for VM to be ready
5. Apply firewall lockdown inside VM
6. Verify isolation (curl to internet should fail, registry should work)

**`scripts/teardown.sh`** - Clean everything:
1. Delete multipass VM
2. Stop and remove registry container
3. Optionally remove registry volume

**`scripts/verify.sh`** - Run inside VM to verify air-gap:
1. `curl https://google.com` should fail/timeout
2. `curl http://<HOST_IP>:5000/v2/_catalog` should succeed
3. `docker pull <HOST_IP>:5000/library/alpine` should succeed
4. DNS resolution should work (`nslookup google.com` resolves but can't connect)

**`scripts/push-image.sh`** - Push a single image to the local registry:
- Usage: `./push-image.sh nginx:1.25`
- Pulls, retags, pushes to local registry

### 6. Image List Management

**File:** `images/required.txt`

A text file listing all images needed in the air-gapped environment:
```
kindest/node:v1.31.0
registry.k8s.io/pause:3.9
registry.k8s.io/coredns/coredns:v1.11.1
registry.k8s.io/etcd:3.5.12-0
registry.k8s.io/kube-apiserver:v1.31.0
registry.k8s.io/kube-controller-manager:v1.31.0
registry.k8s.io/kube-scheduler:v1.31.0
registry.k8s.io/kube-proxy:v1.31.0
```

Users add their application images to this list before running setup.

## Workflow

### First-time setup
```bash
# 1. Start registry and load images (on host, with internet)
./scripts/setup.sh

# 2. SSH into VM
multipass shell airgap-lab

# 3. Verify isolation
./scripts/verify.sh

# 4. Create kind cluster
cd /opt/airgap-lab
./scripts/create-kind.sh
```

### Day-to-day usage
```bash
# Add a new image to the air-gapped environment
# (run on host, with internet access to host registry)
./scripts/push-image.sh myapp:v1.2.3

# Inside VM, pull it
docker pull <HOST_IP>:5000/myapp:v1.2.3
```

### Testing a new build artifact
```bash
# On host: push your built image to the local registry
docker tag myapp:latest localhost:5000/myapp:latest
docker push localhost:5000/myapp:latest

# In VM: deploy it
kubectl set image deployment/myapp myapp=<HOST_IP>:5000/myapp:latest
```

## Project Structure

```
airgap-lab/
├── README.md
├── IMPLEMENTATION_GUIDE.md
├── CLAUDE.md                  # Claude Code instructions for this project
├── registry/
│   └── docker-compose.yml     # Local registry setup
├── vm/
│   ├── cloud-init.yaml        # VM provisioning config
│   └── create-vm.sh           # VM creation script
├── kind/
│   └── kind-config.yaml       # Kind cluster config for air-gap
├── images/
│   └── required.txt           # List of images to pre-load
└── scripts/
    ├── setup.sh               # Full environment setup
    ├── teardown.sh             # Full environment teardown
    ├── lockdown.sh             # Apply firewall rules in VM
    ├── unlock.sh               # Remove firewall rules in VM
    ├── verify.sh               # Verify air-gap isolation
    ├── load-images.sh          # Bulk load images to registry
    ├── push-image.sh           # Push single image to registry
    └── create-kind.sh          # Create kind cluster in VM
```

## Open Questions / Future Enhancements

- **TLS for registry:** Add self-signed CA to simulate corporate PKI
- **Egress whitelisting:** Add ability to whitelist specific external IPs (not just registry) to simulate corporate proxy/firewall rules
- **Minikube support:** Alternative to kind, may need different registry mirror config
- **Nested VMs:** If testing kata-containers or other VM-based runtimes, need KVM passthrough in multipass (`multipass launch --mount` or libvirt)
- **Helm chart mirror:** ChartMuseum or similar for air-gapped Helm chart distribution
- **APT mirror:** For installing packages inside the VM without internet (currently handled by cloud-init at provision time before lockdown)
