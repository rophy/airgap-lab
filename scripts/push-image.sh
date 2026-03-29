#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <image:tag>"
  echo "Example: $0 nginx:1.25"
  exit 1
fi

IMAGE="$1"
REGISTRY="localhost:${REGISTRY_PORT}"
LOCAL_TAG="${REGISTRY}/${IMAGE}"

echo "Pulling ${IMAGE}..."
docker pull "${IMAGE}"

echo "Tagging as ${LOCAL_TAG}..."
docker tag "${IMAGE}" "${LOCAL_TAG}"

echo "Pushing to ${REGISTRY}..."
docker push "${LOCAL_TAG}"

echo "Done: ${LOCAL_TAG}"
