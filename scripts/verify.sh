#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

PASS=0
FAIL=0

check() {
  local desc="$1" expected="$2"
  shift 2
  echo -n "  ${desc}... "
  if "$@" > /dev/null 2>&1; then
    if [[ "${expected}" == "success" ]]; then
      echo "PASS"
      ((PASS++))
    else
      echo "FAIL (should have failed)"
      ((FAIL++))
    fi
  else
    if [[ "${expected}" == "fail" ]]; then
      echo "PASS (correctly blocked)"
      ((PASS++))
    else
      echo "FAIL (should have succeeded)"
      ((FAIL++))
    fi
  fi
}

echo "Verifying air-gap isolation for VM '${VM_NAME}'..."
echo ""

echo "[Network]"
check "Internet access blocked" fail \
  multipass exec "${VM_NAME}" -- curl -s --connect-timeout 5 https://google.com
check "DNS resolution works" success \
  multipass exec "${VM_NAME}" -- nslookup google.com

echo ""
echo "[Registry]"
check "Registry catalog accessible" success \
  multipass exec "${VM_NAME}" -- curl -sf "http://${BRIDGE_HOST_IP}:${REGISTRY_PORT}/v2/_catalog"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ ${FAIL} -eq 0 ]] && echo "All checks passed!" || exit 1
