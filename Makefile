SHELL := /usr/bin/env bash

TOFU_DIR := tofu/envs/proxmox
TOFU     := tofu -chdir=$(TOFU_DIR)

.PHONY: help init fmt validate plan apply output secrets bootstrap workers

help:
	@echo "init      - download providers and write the lock file"
	@echo "fmt       - format all OpenTofu files"
	@echo "validate  - init without backend and validate"
	@echo "plan      - show pending changes"
	@echo "apply     - apply pending changes"
	@echo "output    - show environment outputs"
	@echo "secrets   - generate Talos secrets/configs (WORKERS='...' for workers)"
	@echo "bootstrap - apply control-plane config (needs MAINTENANCE_IP=<DHCP lease>)"
	@echo "workers   - join optional worker VMs (needs WORKER1/2_MAINTENANCE_IP)"

init:
	$(TOFU) init

fmt:
	tofu fmt -recursive tofu

validate:
	$(TOFU) init -backend=false -input=false
	$(TOFU) validate

plan:
	$(TOFU) plan

apply:
	$(TOFU) apply

output:
	$(TOFU) output

secrets:
	./talos/generate.sh

bootstrap:
	@test -n "$(MAINTENANCE_IP)" || { \
		echo "set MAINTENANCE_IP to the Talos maintenance-mode DHCP lease" >&2; \
		echo "e.g. make bootstrap MAINTENANCE_IP=192.168.178.90" >&2; \
		exit 1; \
	}
	MAINTENANCE_IP="$(MAINTENANCE_IP)" ./bootstrap/02-talos.sh

workers:
	./bootstrap/03-workers.sh
