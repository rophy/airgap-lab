# AI Gateway Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an nginx reverse proxy (AI gateway) to the docker-compose stack that forwards LLM API requests from the air-gapped VM to an upstream provider, injecting the API key. Pre-install opencode in the VM configured to use the gateway.

**Architecture:** An nginx container reverse-proxies `/v1/*` requests to a configurable upstream LLM API base URL, injecting an `Authorization` header from a mounted secret file. The VM resolves `ai-gateway.airgap` via dnsmasq to the host bridge IP. opencode inside the VM uses `OPENAI_API_BASE=http://ai-gateway.airgap:8080/v1` with a dummy key.

**Tech Stack:** nginx, docker-compose, bash, cloud-init, dnsmasq (libvirt)

**Spec:** `docs/superpowers/specs/2026-08-10-ai-gateway-design.md`

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `config.sh` | Modify | Add `AI_GATEWAY_HOSTNAME`, `AI_GATEWAY_PORT`, `LLM_API_BASE_URL` |
| `config/egress-whitelist.txt` | Create | Allowed upstream domains (one per line) |
| `config/ai-gateway/nginx.conf.template` | Create | Nginx config template with `${API_KEY}` and `${LLM_API_BASE_URL}` placeholders |
| `config/ai-gateway/entrypoint.sh` | Create | Reads API key, runs envsubst, starts nginx |
| `docker-compose.yaml` | Modify | Add `ai-gateway` service |
| `vm/network.xml` | Modify | Add `AI_GATEWAY_HOSTNAME` to dnsmasq host entries |
| `scripts/setup.sh` | Modify | Add steps to SCP opencode and configure it in the VM |
| `vm/cloud-init.yaml` | Modify | Add opencode env vars to `/etc/environment` |
| `scripts/verify.sh` | Modify | Add AI gateway verification check |

---

### Task 1: Add config variables

**Files:**
- Modify: `config.sh`

- [ ] **Step 1: Add new variables to config.sh**

Add at the end of the file, before the `_CONFIG_DIR` line:

```bash
# AI Gateway (reverse proxy for LLM API access from VM)
AI_GATEWAY_HOSTNAME="${AI_GATEWAY_HOSTNAME:-ai-gateway.airgap}"
AI_GATEWAY_PORT="${AI_GATEWAY_PORT:-8080}"
LLM_API_BASE_URL="${LLM_API_BASE_URL:-https://api.anthropic.com}"
LLM_API_KEY_FILE="${LLM_API_KEY_FILE:-${HOME}/.airgap-lab/api-key}"
```

- [ ] **Step 2: Verify config.sh still sources cleanly**

Run: `bash -n config.sh && echo OK`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add config.sh
git commit -m "feat: add AI gateway config variables"
```

---

### Task 2: Create egress whitelist

**Files:**
- Create: `config/egress-whitelist.txt`

- [ ] **Step 1: Create the whitelist file**

```
api.anthropic.com
api.openai.com
```

Note: The whitelist is currently declarative — it documents which upstream domains are approved. With a single `LLM_API_BASE_URL`, nginx only proxies to one upstream so enforcement is implicit. If multi-upstream support is added later, nginx should validate against this file.

- [ ] **Step 2: Commit**

```bash
git add config/egress-whitelist.txt
git commit -m "feat: add default egress whitelist for AI gateway"
```

---

### Task 3: Create nginx config template and entrypoint

**Files:**
- Create: `config/ai-gateway/nginx.conf.template`
- Create: `config/ai-gateway/entrypoint.sh`

- [ ] **Step 1: Create nginx.conf.template**

```nginx
worker_processes 1;

events {
    worker_connections 128;
}

http {
    resolver 8.8.8.8 ipv6=off;

    server {
        listen 8080;

        location /v1/ {
            proxy_set_header Authorization "Bearer ${API_KEY}";
            proxy_set_header Host ${UPSTREAM_HOST};
            proxy_set_header X-Real-IP $remote_addr;
            proxy_pass ${LLM_API_BASE_URL}/v1/;
            proxy_ssl_server_name on;

            proxy_connect_timeout 30s;
            proxy_read_timeout 120s;
            proxy_send_timeout 30s;
        }

        location /health {
            return 200 'ok';
            add_header Content-Type text/plain;
        }

        location / {
            return 403 'Forbidden: only /v1/* is proxied';
            add_header Content-Type text/plain;
        }
    }
}
```

- [ ] **Step 2: Create entrypoint.sh**

This script reads the API key from the mounted secret, extracts the upstream host from the base URL, substitutes variables into the nginx template, and starts nginx.

```bash
#!/usr/bin/env bash
set -euo pipefail

API_KEY_FILE="${API_KEY_FILE:-/run/secrets/api-key}"
if [[ ! -f "$API_KEY_FILE" ]]; then
  echo "ERROR: API key file not found at $API_KEY_FILE"
  echo "Create it with: echo 'your-key' > ~/.airgap-lab/api-key"
  exit 1
fi

export API_KEY
API_KEY="$(cat "$API_KEY_FILE" | tr -d '[:space:]')"

if [[ -z "$API_KEY" ]]; then
  echo "ERROR: API key file is empty"
  exit 1
fi

if [[ -z "${LLM_API_BASE_URL:-}" ]]; then
  echo "ERROR: LLM_API_BASE_URL is not set"
  exit 1
fi

export UPSTREAM_HOST
UPSTREAM_HOST="$(echo "$LLM_API_BASE_URL" | sed -E 's|https?://([^/]+).*|\1|')"

envsubst '${API_KEY} ${LLM_API_BASE_URL} ${UPSTREAM_HOST}' \
  < /etc/nginx/nginx.conf.template \
  > /etc/nginx/nginx.conf

echo "AI Gateway ready: proxying /v1/* → ${LLM_API_BASE_URL}/v1/"
echo "Upstream host: ${UPSTREAM_HOST}"

exec nginx -g 'daemon off;'
```

- [ ] **Step 3: Make entrypoint executable**

Run: `chmod +x config/ai-gateway/entrypoint.sh`

- [ ] **Step 4: Test entrypoint locally (dry run)**

Run:
```bash
echo "test-key-123" > /tmp/test-api-key
docker run --rm \
  -v $(pwd)/config/ai-gateway/nginx.conf.template:/etc/nginx/nginx.conf.template:ro \
  -v $(pwd)/config/ai-gateway/entrypoint.sh:/entrypoint.sh:ro \
  -v /tmp/test-api-key:/run/secrets/api-key:ro \
  -e LLM_API_BASE_URL=https://api.anthropic.com \
  --entrypoint /entrypoint.sh \
  nginx:alpine
```

Expected output:
```
AI Gateway ready: proxying /v1/* → https://api.anthropic.com/v1/
Upstream host: api.anthropic.com
```

nginx should start without errors. Press Ctrl+C to stop.

- [ ] **Step 5: Clean up and commit**

```bash
rm /tmp/test-api-key
git add config/ai-gateway/
git commit -m "feat: add nginx config template and entrypoint for AI gateway"
```

---

### Task 4: Add ai-gateway service to docker-compose

**Files:**
- Modify: `docker-compose.yaml`

- [ ] **Step 1: Add the ai-gateway service**

Add after the `apt-cache` service:

```yaml
  ai-gateway:
    image: nginx:alpine
    container_name: airgap-ai-gateway
    ports:
      - "${AI_GATEWAY_PORT:-8080}:8080"
    volumes:
      - ./config/ai-gateway/nginx.conf.template:/etc/nginx/nginx.conf.template:ro
      - ./config/ai-gateway/entrypoint.sh:/entrypoint.sh:ro
      - ${LLM_API_KEY_FILE:-~/.airgap-lab/api-key}:/run/secrets/api-key:ro
    environment:
      - LLM_API_BASE_URL=${LLM_API_BASE_URL:-https://api.anthropic.com}
    entrypoint: /entrypoint.sh
    restart: unless-stopped
```

- [ ] **Step 2: Create the API key file on host**

Run:
```bash
mkdir -p ~/.airgap-lab
echo "your-api-key-here" > ~/.airgap-lab/api-key
chmod 600 ~/.airgap-lab/api-key
```

Replace `your-api-key-here` with a real API key.

- [ ] **Step 3: Start the stack and verify gateway starts**

Run:
```bash
source config.sh
docker compose up -d
docker compose logs ai-gateway
```

Expected: logs show "AI Gateway ready: proxying /v1/* → ..." and no errors.

- [ ] **Step 4: Test the gateway from the host**

Run:
```bash
curl -s http://localhost:8080/health
```

Expected: `ok`

Run:
```bash
curl -s http://localhost:8080/
```

Expected: `Forbidden: only /v1/* is proxied`

- [ ] **Step 5: Test a real LLM API call through the gateway**

Run (assuming Anthropic key):
```bash
curl -s http://localhost:8080/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: dummy" \
  -H "anthropic-version: 2023-06-01" \
  -d '{"model":"claude-sonnet-4-20250514","max_tokens":10,"messages":[{"role":"user","content":"hi"}]}' | jq .
```

Expected: a valid response from the Anthropic API (the gateway injected the real key).

Note: if using an OpenAI-compatible endpoint, adjust the request format accordingly.

- [ ] **Step 6: Commit**

```bash
git add docker-compose.yaml
git commit -m "feat: add ai-gateway service to docker-compose"
```

---

### Task 5: Add DNS entry for ai-gateway.airgap

**Files:**
- Modify: `vm/network.xml`
- Modify: `scripts/setup.sh`

- [ ] **Step 1: Add hostname to network.xml**

In `vm/network.xml`, add `AI_GATEWAY_HOSTNAME` to the existing `<host>` block:

```xml
    <host ip='BRIDGE_HOST_IP'>
      <hostname>REGISTRY_HOSTNAME</hostname>
      <hostname>APT_CACHE_HOSTNAME</hostname>
      <hostname>AI_GATEWAY_HOSTNAME</hostname>
    </host>
```

- [ ] **Step 2: Add sed substitution in setup.sh**

In `scripts/setup.sh`, find the `sed` block that renders the network XML (around line 26-33) and add a new `-e` line:

```bash
    -e "s|AI_GATEWAY_HOSTNAME|${AI_GATEWAY_HOSTNAME}|g" \
```

Add it after the `APT_CACHE_HOSTNAME` substitution line.

- [ ] **Step 3: Commit**

```bash
git add vm/network.xml scripts/setup.sh
git commit -m "feat: add ai-gateway.airgap DNS entry to libvirt network"
```

---

### Task 6: Install and configure opencode in the VM

**Files:**
- Modify: `scripts/setup.sh`
- Modify: `vm/cloud-init.yaml`

- [ ] **Step 1: Add opencode env vars to cloud-init.yaml**

Add a new `write_files` section to `vm/cloud-init.yaml` (before `runcmd`):

```yaml
write_files:
  - path: /etc/profile.d/opencode.sh
    content: |
      export OPENAI_API_BASE=http://AI_GATEWAY_HOSTNAME:AI_GATEWAY_PORT/v1
      export OPENAI_API_KEY=dummy
    permissions: '0644'
```

- [ ] **Step 2: Add sed substitutions for AI gateway in vm/create-vm.sh**

Check `vm/create-vm.sh` for the `sed` block that processes cloud-init.yaml. Add substitutions for `AI_GATEWAY_HOSTNAME` and `AI_GATEWAY_PORT`:

```bash
    -e "s|AI_GATEWAY_HOSTNAME|${AI_GATEWAY_HOSTNAME}|g" \
    -e "s|AI_GATEWAY_PORT|${AI_GATEWAY_PORT}|g" \
```

- [ ] **Step 3: Add opencode SCP step to setup.sh**

Add after the "Creating VM" step (step 3), before "Starting local registry" (step 4). The VM needs to be booted and SSH-ready:

```bash
# Step 3b: Install opencode in VM
OPENCODE_BIN="$(which opencode 2>/dev/null || echo "${HOME}/.opencode/bin/opencode")"
if [[ -f "${OPENCODE_BIN}" ]]; then
  echo "[3b/5] Installing opencode in VM..."
  scp -o StrictHostKeyChecking=no -o BatchMode=yes \
    "${OPENCODE_BIN}" "ubuntu@${BRIDGE_VM_IP}:/tmp/opencode"
  ssh -o StrictHostKeyChecking=no -o BatchMode=yes \
    "ubuntu@${BRIDGE_VM_IP}" "sudo mv /tmp/opencode /usr/local/bin/opencode && sudo chmod +x /usr/local/bin/opencode"
  echo "  opencode installed."
else
  echo "[3b/5] Skipping opencode install (binary not found on host)."
fi
```

- [ ] **Step 4: Commit**

```bash
git add scripts/setup.sh vm/cloud-init.yaml vm/create-vm.sh
git commit -m "feat: install and configure opencode in VM via cloud-init and SCP"
```

---

### Task 7: Add AI gateway verification to verify.sh

**Files:**
- Modify: `scripts/verify.sh`

- [ ] **Step 1: Check current verify.sh structure**

Read `scripts/verify.sh` to understand the existing test pattern (how PASS/FAIL is reported).

- [ ] **Step 2: Add gateway health check**

Add a new check section after the existing `[Registry]` section:

```bash
[AI Gateway]
  Gateway health check:
```

The check should SSH into the VM and run:
```bash
curl -sf http://ai-gateway.airgap:8080/health
```

Expected: exits 0, prints `ok` → PASS.
If the gateway container isn't running, it exits non-zero → FAIL.

Follow the same `run_check` / reporting pattern used by the existing checks.

- [ ] **Step 3: Add opencode installation check**

Add another check:
```bash
  opencode installed:
```

SSH into the VM and run:
```bash
which opencode
```

Expected: exits 0 → PASS.

- [ ] **Step 4: Test verify.sh (without VM running)**

Run: `./scripts/verify.sh 2>&1`

The new checks should FAIL cleanly (VM is down). Existing checks should also FAIL. No crashes.

- [ ] **Step 5: Commit**

```bash
git add scripts/verify.sh
git commit -m "feat: add AI gateway and opencode checks to verify.sh"
```

---

### Task 8: Update documentation

**Files:**
- Modify: `README.md`
- Modify: `config/egress-whitelist.txt` (if needed)

- [ ] **Step 1: Add AI Gateway section to README.md**

Add after the "Temporarily Allowing Internet" section:

```markdown
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
LLM_API_BASE_URL="https://api.anthropic.com"  # default
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
```

- [ ] **Step 2: Add AI_GATEWAY variables to the Configuration table**

Add to the existing config table in README.md:

```markdown
| `AI_GATEWAY_HOSTNAME` | `ai-gateway.airgap` | AI gateway hostname |
| `AI_GATEWAY_PORT` | `8080` | AI gateway port |
| `LLM_API_BASE_URL` | `https://api.anthropic.com` | Upstream LLM API URL |
| `LLM_API_KEY_FILE` | `~/.airgap-lab/api-key` | Path to API key file |
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add AI gateway section to README"
```

---

### Task 9: End-to-end test

This task requires the full lab to be running.

- [ ] **Step 1: Set up API key**

```bash
mkdir -p ~/.airgap-lab
# Put a real API key in here
echo "sk-..." > ~/.airgap-lab/api-key
chmod 600 ~/.airgap-lab/api-key
```

- [ ] **Step 2: Run full setup**

```bash
./scripts/setup.sh
```

All steps should pass, including opencode SCP.

- [ ] **Step 3: Run verification**

```bash
./scripts/verify.sh
```

All checks should pass, including the new AI gateway and opencode checks.

- [ ] **Step 4: Test opencode from inside the VM**

```bash
ssh ubuntu@10.99.0.10
opencode run "say hello"
```

Expected: opencode sends the request through the gateway, gets a response from the LLM.

- [ ] **Step 5: Verify air-gap is intact**

```bash
ssh ubuntu@10.99.0.10 "curl -sf --connect-timeout 3 https://google.com && echo LEAKED || echo BLOCKED"
```

Expected: `BLOCKED`

- [ ] **Step 6: Verify gateway blocks non-v1 paths**

```bash
ssh ubuntu@10.99.0.10 "curl -s http://ai-gateway.airgap:8080/"
```

Expected: `Forbidden: only /v1/* is proxied`
