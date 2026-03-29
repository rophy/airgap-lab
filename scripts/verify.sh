#!/usr/bin/env bash
set -euo pipefail

HOST_IP=$(ip route | grep default | awk '{print $3}')
REGISTRY_PORT=5000
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

echo "Verifying air-gap isolation..."
echo ""

echo "[Network]"
check "Internet access blocked" fail curl -s --connect-timeout 5 https://google.com
check "DNS resolution works" success nslookup google.com

echo ""
echo "[Registry]"
check "Registry catalog accessible" success curl -sf "http://${HOST_IP}:${REGISTRY_PORT}/v2/_catalog"
check "Docker pull from registry" success docker pull "${HOST_IP}:${REGISTRY_PORT}/registry.k8s.io/pause:3.9"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ ${FAIL} -eq 0 ]] && echo "All checks passed!" || exit 1
