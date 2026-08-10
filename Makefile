SHELL := /bin/bash

VM_NAME     := $(shell source config.sh && echo $$VM_NAME)
BRIDGE_VM_IP := $(shell source config.sh && echo $$BRIDGE_VM_IP)

.PHONY: status setup teardown ssh verify

status:
	@echo "=== Services ==="
	@docker compose ps --format 'table {{.Name}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || echo "  (not running)"
	@echo ""
	@echo "=== VM ==="
	@virsh list --all 2>/dev/null | grep -E "$(VM_NAME)|Name" || echo "  (not found)"
	@echo ""
	@echo "VM IP: $(BRIDGE_VM_IP)"

setup:
	./scripts/setup.sh

teardown:
	./scripts/teardown.sh

ssh:
	ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@$(BRIDGE_VM_IP)

verify:
	./scripts/verify.sh
