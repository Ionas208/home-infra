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
	@echo "secrets   - generate Talos secrets and machine configs"
	@echo "bootstrap - apply control-plane config, bootstrap etcd, write kubeconfig"
	@echo "workers   - join the worker VMs to the cluster"

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
	./bootstrap/02-talos.sh

workers:
	./bootstrap/03-workers.sh
