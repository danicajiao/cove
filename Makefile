# Cove monorepo — local build targets
#
# These targets are for local development only. CI uses Docker and GitHub
# Actions directly. Run `make help` to see available targets.

COMMIT_SHA := $(shell git rev-parse --short HEAD 2>/dev/null || echo dev)

# ── Docker image targets ────────────────────────────────────────────────────

.PHONY: build-cove-api
build-cove-api: ## Build the cove-api Docker image
	docker build \
		--build-arg COMMIT_SHA=$(COMMIT_SHA) \
		-t cove-api:$(COMMIT_SHA) \
		apps/cove-api/

.PHONY: build-all
build-all: build-cove-api ## Build Docker images for all services

# ── Go tooling ──────────────────────────────────────────────────────────────

.PHONY: lint
lint: ## Run linters for all services
	cd apps/cove-api && go vet ./...

.PHONY: test
test: ## Run tests for all services
	cd apps/cove-api && go test ./...

# ── Help ────────────────────────────────────────────────────────────────────

.PHONY: help
help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
