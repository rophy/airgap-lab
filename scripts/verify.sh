#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

BRIDGE_VM_IP="${BRIDGE_VM_IP:-10.99.0.10}"
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes ubuntu@${BRIDGE_VM_IP}"

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
  ${SSH} "curl -s --connect-timeout 5 https://google.com"
check "DNS resolution blocked" fail \
  ${SSH} "nslookup google.com"

echo ""
echo "[Registry]"
check "Registry catalog accessible" success \
  ${SSH} "curl -sf http://${BRIDGE_HOST_IP}:${REGISTRY_PORT}/v2/_catalog"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ ${FAIL} -eq 0 ]] && echo "All checks passed!" || exit 1
