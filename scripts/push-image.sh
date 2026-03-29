#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <image:tag>"
  echo "Example: $0 nginx:1.25"
  exit 1
fi

IMAGE="$1"
REGISTRY="${AIRGAP_REGISTRY:-localhost:5000}"
LOCAL_TAG="${REGISTRY}/${IMAGE}"

echo "Pulling ${IMAGE}..."
docker pull "${IMAGE}"

echo "Tagging as ${LOCAL_TAG}..."
docker tag "${IMAGE}" "${LOCAL_TAG}"

echo "Pushing to ${REGISTRY}..."
docker push "${LOCAL_TAG}"

echo "Done: ${LOCAL_TAG}"
