#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.sh"

SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes ubuntu@${BRIDGE_VM_IP}"

PASS=0
FAIL=0

check() {
  local desc="$1" expected="$2"
  shift 2
  echo "  ${desc}:"
  local output rc=0
  output=$("$@" 2>&1) || rc=$?
  if [[ -n "${output}" ]]; then
    echo "${output}" | sed 's/^/    /'
  fi
  echo -n "    -> "
  if [[ ${rc} -eq 0 ]]; then
    if [[ "${expected}" == "success" ]]; then
      echo "PASS (exit ${rc})"
      PASS=$((PASS + 1))
    else
      echo "FAIL (exit ${rc}, should have failed)"
      FAIL=$((FAIL + 1))
    fi
  else
    if [[ "${expected}" == "fail" ]]; then
      echo "PASS (exit ${rc}, correctly blocked)"
      PASS=$((PASS + 1))
    else
      echo "FAIL (exit ${rc}, should have succeeded)"
      FAIL=$((FAIL + 1))
    fi
  fi
  echo ""
}

echo "Verifying air-gap isolation for VM '${VM_NAME}'..."
echo ""

echo "[Network]"
check "Internet access blocked" fail \
  timeout 10 ${SSH} "curl -s --connect-timeout 5 https://google.com"
check "DNS resolution works" success \
  timeout 10 ${SSH} "timeout 5 nslookup google.com"

echo "[Registry]"
check "Registry hostname resolves" success \
  timeout 10 ${SSH} "timeout 5 nslookup ${REGISTRY_HOSTNAME}"
check "Registry catalog accessible" success \
  ${SSH} "curl -sf http://${REGISTRY_HOSTNAME}:${REGISTRY_PORT}/v2/_catalog"

echo "[AI Gateway]"
check "Gateway health check" success \
  ${SSH} "curl -sf http://${AI_GATEWAY_HOSTNAME}:${AI_GATEWAY_PORT}/health"
check "opencode installed" success \
  ${SSH} "which opencode"

echo "Results: ${PASS} passed, ${FAIL} failed"
[[ ${FAIL} -eq 0 ]] && echo "All checks passed!" || exit 1
