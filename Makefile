SHELL := /bin/bash

VM_NAME     := $(shell source config.sh && echo $$VM_NAME)
BRIDGE_VM_IP := $(shell source config.sh && echo $$BRIDGE_VM_IP)

.PHONY: help status setup teardown ssh verify

help: ## Show available targets
	@grep -E '^[a-z]+:.*##' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  make %-12s %s\n", $$1, $$2}'

status: ## Show services and VM state
	@echo "=== Services ==="
	@docker compose ps --format 'table {{.Name}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || echo "  (not running)"
	@echo ""
	@echo "=== VM ==="
	@virsh list --all 2>/dev/null | grep -E "$(VM_NAME)|Name" || echo "  (not found)"
	@echo ""
	@echo "VM IP: $(BRIDGE_VM_IP)"

setup: ## Set up everything (network, VM, services)
	./scripts/setup.sh

teardown: ## Remove VM, network, and stop services
	./scripts/teardown.sh

ssh: ## SSH into the VM
	ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@$(BRIDGE_VM_IP)

verify: ## Verify air-gap isolation
	./scripts/verify.sh
