# AI Gateway for Air-Gapped VM

## Problem

Running an AI coding agent (opencode) inside the air-gapped VM requires LLM API access. The VM has no internet by design. We need a controlled egress path that forwards only LLM API traffic while keeping the air-gap intact for everything else.

## Design

### Architecture

```
VM (air-gapped)                    Host
┌─────────────────┐    ┌──────────────────────────┐
│ opencode         │    │                          │
│   → ai-gateway   │────│→ nginx (ai-gateway)      │──→ upstream LLM API
│     .airgap:8080 │    │   injects API key        │
│                  │    │   checks whitelist        │
│ docker           │    │                          │
│   → registry     │────│→ registry:5000           │
│     .airgap:5000 │    │                          │
│ apt              │    │                          │
│   → apt-proxy    │────│→ apt-cacher-ng:3142      │
│     .airgap:3142 │    │                          │
└─────────────────┘    └──────────────────────────┘
```

### AI Gateway (nginx reverse proxy)

A new `ai-gateway` service in `docker-compose.yaml`. Nginx reverse-proxies requests from the VM to the upstream LLM API.

**Responsibilities:**
- Reverse-proxy requests from `http://ai-gateway.airgap:8080/v1/*` to the configured upstream LLM API base URL
- Inject `Authorization: Bearer <key>` header on all forwarded requests — the VM never sees the real API key
- Validate the upstream target against a whitelist of allowed domains — return 403 for non-whitelisted upstreams
- OpenAI-compatible: the gateway is a transparent pass-through that adds auth, so any OpenAI-compatible client works

**Container config:**
- Image: `nginx:alpine`
- Port: `8080` on the host (bound to bridge interface)
- Mounts:
  - `config/ai-gateway/nginx.conf` — nginx config with reverse proxy rules
  - `config/egress-whitelist.txt` — allowed upstream domains
  - `~/.airgap-lab/api-key` — API key file (read-only, not committed)

### Configuration

**New variables in `config.sh`:**

| Variable | Default | Description |
|---|---|---|
| `AI_GATEWAY_HOSTNAME` | `ai-gateway.airgap` | Gateway hostname resolved by dnsmasq |
| `AI_GATEWAY_PORT` | `8080` | Gateway port |
| `LLM_API_BASE_URL` | `https://api.anthropic.com` | Upstream LLM API base URL |

**New files:**

| File | Purpose | Committed? |
|---|---|---|
| `config/ai-gateway/nginx.conf` | Nginx reverse proxy config (template) | Yes |
| `config/egress-whitelist.txt` | Allowed upstream domains, one per line | Yes (with defaults) |
| `~/.airgap-lab/api-key` | API key for the upstream LLM API | No (user-provided) |

**`config/egress-whitelist.txt` default content:**
```
api.anthropic.com
api.openai.com
```

### DNS

Add `ai-gateway.airgap` to `vm/network.xml` dnsmasq host entries, pointing at the host bridge IP (`BRIDGE_HOST_IP`) alongside existing entries:

```xml
<host ip='BRIDGE_HOST_IP'>
  <hostname>REGISTRY_HOSTNAME</hostname>
  <hostname>APT_CACHE_HOSTNAME</hostname>
  <hostname>AI_GATEWAY_HOSTNAME</hostname>
</host>
```

### opencode in the VM

**Installation:**
- Binary SCP'd from host to VM during `setup.sh` (after VM boot), not downloaded via the gateway
- Keeps the whitelist strictly LLM-API-only — no GitHub releases needed

**Configuration (written by setup.sh):**
- `OPENAI_API_BASE=http://ai-gateway.airgap:8080/v1`
- `OPENAI_API_KEY=dummy` (gateway handles real auth; some clients require a non-empty key)

**Usage:**
```bash
ssh ubuntu@10.99.0.10
opencode
```

### docker-compose.yaml changes

```yaml
ai-gateway:
  image: nginx:alpine
  container_name: airgap-ai-gateway
  ports:
    - "${AI_GATEWAY_PORT:-8080}:8080"
  volumes:
    - ./config/ai-gateway/nginx.conf:/etc/nginx/nginx.conf:ro
    - ./config/egress-whitelist.txt:/etc/nginx/egress-whitelist.txt:ro
    - ${HOME}/.airgap-lab/api-key:/run/secrets/api-key:ro
  restart: unless-stopped
```

### nginx.conf outline

The `nginx.conf` is a template. At container startup, an entrypoint script reads `~/.airgap-lab/api-key` and substitutes `LLM_API_BASE_URL` and the API key into the nginx config using `envsubst`, then starts nginx. This avoids needing Lua/njs modules.

```nginx
server {
    listen 8080;

    location /v1/ {
        proxy_set_header Authorization "Bearer ${API_KEY}";
        proxy_set_header Host ${UPSTREAM_HOST};
        proxy_pass ${LLM_API_BASE_URL}/v1/;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_ssl_server_name on;
    }
}
```

The whitelist check can be implemented as an nginx `map` block loaded from the whitelist file, returning 403 for non-matches.

### setup.sh changes

After VM boot (existing step 3), add:
1. SCP opencode binary into the VM
2. Write opencode config with gateway endpoint

### Error handling

- Gateway returns 502 if the upstream LLM API is unreachable (host has no internet)
- Gateway returns 403 if the upstream domain is not in the whitelist
- If `~/.airgap-lab/api-key` is missing, the gateway container fails to start with a clear error

## Out of scope

- TLS on the gateway (the VM-to-host link is a local bridge, not a network boundary)
- Multiple API keys for different providers (single key for now; extend later if needed)
- Rate limiting or usage tracking
