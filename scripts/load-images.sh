#!/usr/bin/env bash
set -euo pipefail

IMAGE_LIST="${1:-images/required.txt}"
REGISTRY="${AIRGAP_REGISTRY:-localhost:5000}"

if [[ ! -f "${IMAGE_LIST}" ]]; then
  echo "Error: image list not found: ${IMAGE_LIST}"
  exit 1
fi

while IFS= read -r image; do
  # Skip empty lines and comments
  [[ -z "${image}" || "${image}" =~ ^# ]] && continue

  echo "==> Processing: ${image}"

  # Pull from upstream
  docker pull "${image}"

  # Retag for local registry
  local_tag="${REGISTRY}/${image}"
  docker tag "${image}" "${local_tag}"

  # Push to local registry
  docker push "${local_tag}"

  echo "==> Pushed: ${local_tag}"
done < "${IMAGE_LIST}"

echo "All images loaded."
