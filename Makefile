# Oh My Pi Docker — Makefile
# Primary interface for all docker operations

# Load env files (defaults first; .env.properties is optional for local overrides)
-include .env.default.properties
-include .env.properties

# Export config so docker compose sees actual values (not just Make-internal vars)
export WORKSPACE_DIR
export OMP_STATE_DIR
export SSH_DIR
export GIT_SIGNING_KEY
export RESOURCE_CPUS
export RESOURCE_MEMORY

# Auto-detect host .gitconfig for git identity in container
# Only mount when the file exists — Docker would create a directory otherwise
GITCONFIG_FILE := $(HOME)/.gitconfig
ifneq ($(wildcard $(GITCONFIG_FILE)),)
export GITCONFIG=$(GITCONFIG_FILE)
endif

# Resolve compose file path
COMPOSE_FILE := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))compose.yaml

# Default target
.DEFAULT_GOAL := help

# Help target
help: ## Show this help
	@grep -hE '^[a-zA-Z_.-]+:.*## ' $(MAKEFILE_LIST) | awk -F'## ' '{split($$1, a, ":"); printf "\033[36m%-20s\033[0m %s\n", a[1], $$2}' | sort

# Forward extra command-line goals as arguments to docker.run.
# Handles `make docker.run -- --resume` by capturing --resume
# as a container argument instead of a Make target.
_KNOWN_TARGETS := help _ensure_entrypoint \
  docker docker.build docker.run docker.run.d \
  docker.stop docker.clean docker.update docker.ls \
  install uninstall
_EXTRAS := $(filter-out $(_KNOWN_TARGETS),$(MAKECMDGOALS))
ifneq ($(_EXTRAS),)
  ARGS ?= -- $(_EXTRAS)
  .PHONY: $(_EXTRAS)
  $(_EXTRAS): ;@true
endif


# Ensure entrypoint is executable (idempotent; run before any docker compose call)
_ensure_entrypoint:
	@chmod +x entrypoint.sh
.PHONY: _ensure_entrypoint

# Docker targets
docker: docker.build docker.run ## Build and run interactively

docker.build: _ensure_entrypoint ## Build the Docker image
	docker compose -f $(COMPOSE_FILE) build

docker.run: _ensure_entrypoint ## Run interactively
	docker compose -f $(COMPOSE_FILE) run --rm omp $(ARGS)

docker.run.d: _ensure_entrypoint ## Run detached
	docker compose -f $(COMPOSE_FILE) up -d

docker.stop: ## Stop containers
	docker compose -f $(COMPOSE_FILE) down

docker.clean: ## Remove untagged images
	docker compose -f $(COMPOSE_FILE) down --rmi all

docker.update: _ensure_entrypoint ## Rebuild from update stage (cache-busting)
	docker compose -f $(COMPOSE_FILE) build --build-arg update-token="$$(date +%s)"

docker.ls: ## List project images
	@docker images | grep -E "omp|REPOSITORY"

# Wrapper scripts: each maps a CLI name to a make target
WRAPPERS := omp-docker:docker.run omp-docker-build:docker.build omp-docker-update:docker.update
MAKE_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

install: docker.build ## Build image and create wrapper scripts
	@mkdir -p ~/.omp ~/.local/bin
	@for spec in $(WRAPPERS); do \
	  name=$${spec%%:*}; target=$${spec##*:}; \
	  printf '#!/usr/bin/env bash\nexec make -C "$(MAKE_DIR)" %s ARGS="$$*"\n' "$$target" > ~/.local/bin/"$$name"; \
	  chmod +x ~/.local/bin/"$$name"; \
	done
	@echo "Installed: $(shell echo $(WRAPPERS) | sed 's/:[^ ]*//g' | sed 's/ /, ~\//g' | sed 's/^/~/')"

uninstall: docker.stop ## Remove containers, images, and wrapper scripts
	@for spec in $(WRAPPERS); do rm -f ~/.local/bin/$${spec%%:*}; done
	@echo "Uninstalled wrapper scripts"
