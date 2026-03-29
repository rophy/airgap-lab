#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

IMAGE_LIST="${1:-${SCRIPT_DIR}/../images/required.txt}"
REGISTRY="localhost:${REGISTRY_PORT}"

if [[ ! -f "${IMAGE_LIST}" ]]; then
  echo "Error: image list not found: ${IMAGE_LIST}"
  exit 1
fi

while IFS= read -r image; do
  # Skip empty lines and comments
  [[ -z "${image}" || "${image}" =~ ^# ]] && continue

  echo "==> Processing: ${image}"

  docker pull "${image}"

  local_tag="${REGISTRY}/${image}"
  docker tag "${image}" "${local_tag}"
  docker push "${local_tag}"

  echo "==> Pushed: ${local_tag}"
done < "${IMAGE_LIST}"

echo "All images loaded."
