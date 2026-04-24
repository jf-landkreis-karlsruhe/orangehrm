.PHONY: help \
        build-dev-images dev-down test-php test-js lint lint-php lint-js fix-php fix-js shell-php shell-js \
        local-build local-up local-down local-logs local-reset

# Colors
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

# Compose stacks
DEV_COMPOSE   := docker compose -f docker/dev/docker-compose.yml
LOCAL_COMPOSE := docker compose -f docker/local/docker-compose.yml

# Stamp file marking that the test DB has been installed in this dev session.
# Lives inside docker/dev/ so it is git-ignored implicitly via gitignore patterns.
TEST_DB_STAMP := docker/dev/.test-db-installed

# Auto-create .env so UID/GID get baked into the dev images.
.env:
	@if [ ! -f .env ]; then \
		echo "$(YELLOW)Creating .env file...$(NC)"; \
		if [ -f .env.dev.example ]; then \
			cp .env.dev.example .env; \
			echo "UID=$$(id -u)" >> .env; \
			echo "GID=$$(id -g)" >> .env; \
		else \
			echo "UID=$$(id -u)" > .env; \
			echo "GID=$$(id -g)" >> .env; \
			echo "XDEBUG_MODE=off" >> .env; \
		fi; \
		echo "$(GREEN).env created with your UID/GID$(NC)"; \
	fi

help: ## Show this help
	@echo "$(BLUE)OrangeHRM dev workflow$(NC)"
	@echo ""
	@echo "$(YELLOW)Tools (code is bind-mounted, vendor/node_modules live in the image):$(NC)"
	@awk 'BEGIN {FS = ":.*##"} /^(build-dev-images|dev-down|test-php|test-js|lint|lint-php|lint-js|fix-php|fix-js|shell-php|shell-js):.*##/ { printf "  $(BLUE)%-20s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)Local live app (image built from current code, no mount):$(NC)"
	@awk 'BEGIN {FS = ":.*##"} /^(local-build|local-up|local-down|local-logs|local-reset):.*##/ { printf "  $(BLUE)%-20s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""

# ---------------------------------------------------------------------------
# Dev/test images
# ---------------------------------------------------------------------------

build-dev-images: .env ## Build php-tools and node-tools images (run after composer.lock / yarn.lock changes)
	@echo "$(BLUE)Building dev images...$(NC)"
	@$(DEV_COMPOSE) build php-tools node-tools
	@echo "$(YELLOW)Note: also run 'make dev-down' to discard old vendor/node_modules volumes.$(NC)"

dev-down: .env ## Stop dev containers and remove anonymous volumes (clears test DB stamp)
	@$(DEV_COMPOSE) down -v
	@rm -f $(TEST_DB_STAMP)

# Install OrangeHRM into the test DB and create the test fixtures DB.
# Idempotent via a stamp file; cleared on dev-down (tmpfs is wiped anyway).
$(TEST_DB_STAMP): .env
	@echo "$(BLUE)Setting up test database...$(NC)"
	@$(DEV_COMPOSE) up -d mariadb-test
	@echo "$(BLUE)Waiting for MariaDB...$(NC)"
	@$(DEV_COMPOSE) exec -T mariadb-test sh -c 'until mysqladmin ping -h localhost -proot --silent; do sleep 1; done'
	@echo "$(BLUE)Clearing previous install state (lib/confs/Conf.php, cryptokeys)...$(NC)"
	@rm -f lib/confs/Conf.php
	@rm -rf lib/confs/cryptokeys
	@sed -i.bak \
		-e 's/hostName: 127\.0\.0\.1/hostName: mariadb-test/' \
		-e 's/isExistingDatabase: n/isExistingDatabase: y/' \
		installer/cli_install_config.yaml
	@$(DEV_COMPOSE) run --rm php-tools php installer/cli_install.php; \
		EXIT=$$?; \
		mv installer/cli_install_config.yaml.bak installer/cli_install_config.yaml; \
		if [ $$EXIT -ne 0 ]; then exit $$EXIT; fi
	@$(DEV_COMPOSE) run --rm php-tools php devTools/core/console.php i:create-test-db -p root
	@mkdir -p $(dir $(TEST_DB_STAMP))
	@touch $(TEST_DB_STAMP)
	@echo "$(GREEN)Test database ready.$(NC)"

test-php: $(TEST_DB_STAMP) ## Run PHPUnit (pass extra flags via ARGS=...)
	@$(DEV_COMPOSE) run --rm php-tools php -d memory_limit=1G ./src/vendor/bin/phpunit $(ARGS)

test-js: .env ## Run Jest unit tests (pass extra flags via ARGS=...)
	@$(DEV_COMPOSE) run --rm node-tools sh -c "cd src/client && yarn test:unit $(ARGS)"

lint: lint-php lint-js ## Run all linters (no fixes)

lint-php: .env ## Check PHP coding standards (matches CI: --php php8.3)
	@$(DEV_COMPOSE) run --rm php-tools php devTools/core/console.php php-cs-fix --php php8.3

fix-php: .env ## Apply PHP coding-standard fixes on host files
	@$(DEV_COMPOSE) run --rm php-tools php devTools/core/console.php php-cs-fix --php php8.3 --fix

lint-js: .env ## Lint all JS workspaces
	@$(DEV_COMPOSE) run --rm node-tools sh -c "cd src/client && yarn lint"
	@$(DEV_COMPOSE) run --rm node-tools sh -c "cd installer/client && yarn lint"
	@$(DEV_COMPOSE) run --rm node-tools sh -c "cd src/test/functional && yarn lint"

fix-js: .env ## Apply ESLint --fix in all JS workspaces (writes to host files)
	@$(DEV_COMPOSE) run --rm node-tools sh -c "cd src/client && yarn lint --fix"
	@$(DEV_COMPOSE) run --rm node-tools sh -c "cd installer/client && yarn lint --fix"
	@$(DEV_COMPOSE) run --rm node-tools sh -c "cd src/test/functional && yarn lint --fix"

shell-php: .env ## Interactive shell in php-tools
	@$(DEV_COMPOSE) run --rm php-tools bash

shell-js: .env ## Interactive shell in node-tools
	@$(DEV_COMPOSE) run --rm node-tools bash

# ---------------------------------------------------------------------------
# Local "live app": base + app images, MariaDB, no bind mount
# ---------------------------------------------------------------------------

local-build: ## Build the base image (cached) and the app image from current code
	@echo "$(BLUE)Building local base image...$(NC)"
	@docker build -t orangehrm-local-base:latest -f docker/local/Dockerfile.base .
	@echo "$(BLUE)Building local app image (composer install + yarn build)...$(NC)"
	@$(LOCAL_COMPOSE) build app

local-up: ## Start the local live app at http://localhost:8080
	@$(LOCAL_COMPOSE) up -d
	@echo "$(GREEN)Local app: http://localhost:8080$(NC)"
	@echo "$(YELLOW)First boot runs cli_install.php (~30s). Tail with 'make local-logs'.$(NC)"

local-down: ## Stop local live app (DB and install state are preserved)
	@$(LOCAL_COMPOSE) down

local-logs: ## Tail logs of the local app container
	@$(LOCAL_COMPOSE) logs -f app

local-reset: ## Stop and wipe DB + install state volumes (next local-up reinstalls)
	@$(LOCAL_COMPOSE) down -v
	@echo "$(GREEN)Local volumes removed.$(NC)"
