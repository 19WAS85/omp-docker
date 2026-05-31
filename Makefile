# Oh My Pi Docker — Makefile
# Primary interface for all docker operations

# Load env files (order matters: defaults first, then overrides)
-include .env.default.properties
-include .env.properties

# Resolve compose file path
COMPOSE_FILE := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))compose.yaml

# Default target
.DEFAULT_GOAL := help

# Help target
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Docker targets
docker: docker.build docker.run ## Build and run interactively

docker.build: ## Build the Docker image
	@chmod +x entrypoint.sh
	docker compose -f $(COMPOSE_FILE) build

docker.run: ## Run interactively
	@chmod +x entrypoint.sh
	OMP_WORKDIR="$$PWD" docker compose -f $(COMPOSE_FILE) run --rm omp

docker.run.d: ## Run detached
	@chmod +x entrypoint.sh
	docker compose -f $(COMPOSE_FILE) up -d

docker.stop: ## Stop containers
	docker compose -f $(COMPOSE_FILE) down

docker.clean: ## Remove untagged images
	docker compose -f $(COMPOSE_FILE) down --rmi all

docker.update: ## Rebuild from update stage (cache-busting)
	@chmod +x entrypoint.sh
	docker compose -f $(COMPOSE_FILE) build --build-arg update-token="$$(date +%s)"

docker.ls: ## List project images
	@docker images | grep -E "omp|REPOSITORY"

# Setup targets
install: docker.build ## Build image and create wrapper scripts
	@mkdir -p ~/.omp
	@mkdir -p ~/.local/bin
	@echo '#!/usr/bin/env bash' > ~/.local/bin/omp-docker
	@echo 'exec make -C "$(dir $(realpath $(lastword $(MAKEFILE_LIST))))" docker.run "$$@"' >> ~/.local/bin/omp-docker
	@chmod +x ~/.local/bin/omp-docker
	@echo '#!/usr/bin/env bash' > ~/.local/bin/omp-docker-build
	@echo 'exec make -C "$(dir $(realpath $(lastword $(MAKEFILE_LIST))))" docker.build "$$@"' >> ~/.local/bin/omp-docker-build
	@chmod +x ~/.local/bin/omp-docker-build
	@echo '#!/usr/bin/env bash' > ~/.local/bin/omp-docker-update
	@echo 'exec make -C "$(dir $(realpath $(lastword $(MAKEFILE_LIST))))" docker.update "$$@"' >> ~/.local/bin/omp-docker-update
	@chmod +x ~/.local/bin/omp-docker-update
	@echo "Installed: ~/.local/bin/omp-docker, ~/.local/bin/omp-docker-build, ~/.local/bin/omp-docker-update"

uninstall: docker.stop ## Remove containers, images, and wrapper scripts
	@rm -f ~/.local/bin/omp-docker
	@rm -f ~/.local/bin/omp-docker-build
	@rm -f ~/.local/bin/omp-docker-update
	@echo "Uninstalled wrapper scripts"
