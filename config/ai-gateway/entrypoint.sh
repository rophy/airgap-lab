#!/bin/sh
set -eu

API_KEY_FILE="${API_KEY_FILE:-/run/secrets/api-key}"
if [ ! -f "$API_KEY_FILE" ]; then
  echo "ERROR: API key file not found at $API_KEY_FILE"
  echo "Create it with: echo 'your-key' > ~/.airgap-lab/api-key"
  exit 1
fi

export API_KEY
API_KEY="$(cat "$API_KEY_FILE" | tr -d '[:space:]')"

if [ -z "$API_KEY" ]; then
  echo "ERROR: API key file is empty"
  exit 1
fi

if [ -z "${LLM_API_BASE_URL:-}" ]; then
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
