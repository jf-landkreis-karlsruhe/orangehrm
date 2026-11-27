.PHONY: help \
        build-dev-images dev-down deps test-php test-js lint lint-php lint-js fix-php fix-js shell-php shell-js \
        local-build local-up local-down local-logs local-reset \
        sandbox sandbox-rm

# Colors
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

# Compose stacks
DEV_COMPOSE   := docker compose -f docker/dev/docker-compose.yml
LOCAL_COMPOSE := docker compose -f docker/local/docker-compose.yml

# Inside the Docker Sandbox (ORANGEHRM_SANDBOX is set by .sbx/orangehrm) the
# tools run natively against MariaDB on 127.0.0.1; on the host they run in the
# docker/dev containers.
#
# Stamp files marking that the test DB has been installed in this dev session.
# Live inside docker/dev/ so they are git-ignored implicitly via gitignore patterns.
# Host and sandbox share lib/confs/Conf.php, so installing one invalidates the other.
ifdef ORANGEHRM_SANDBOX
TEST_DB_STAMP       := docker/dev/.test-db-installed-sandbox
OTHER_TEST_DB_STAMP := docker/dev/.test-db-installed
DOCKER_ENV          :=
PHP_DEPS            := src/vendor/autoload.php devTools/core/vendor/autoload.php
JS_DEPS             := src/client/node_modules/.yarn-state.yml \
                       installer/client/node_modules/.yarn-state.yml \
                       src/test/functional/node_modules/.yarn-state.yml
PHP_RUN             :=
NODE_RUN            := sh -c
else
TEST_DB_STAMP       := docker/dev/.test-db-installed
OTHER_TEST_DB_STAMP := docker/dev/.test-db-installed-sandbox
DOCKER_ENV          := .env
PHP_DEPS            := .env
JS_DEPS             := .env
PHP_RUN             := $(DEV_COMPOSE) run --rm php-tools
NODE_RUN            := $(DEV_COMPOSE) run --rm node-tools sh -c
endif

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
	@awk 'BEGIN {FS = ":.*##"} /^(build-dev-images|dev-down|deps|test-php|test-js|lint|lint-php|lint-js|fix-php|fix-js|shell-php|shell-js):.*##/ { printf "  $(BLUE)%-20s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)Local live app (image built from current code, no mount):$(NC)"
	@awk 'BEGIN {FS = ":.*##"} /^(local-build|local-up|local-down|local-logs|local-reset):.*##/ { printf "  $(BLUE)%-20s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)Claude Code in a Docker Sandbox (sbx, run on the host):$(NC)"
	@awk 'BEGIN {FS = ":.*##"} /^(sandbox|sandbox-rm):.*##/ { printf "  $(BLUE)%-20s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""

# ---------------------------------------------------------------------------
# Dev/test images
# ---------------------------------------------------------------------------

build-dev-images: $(DOCKER_ENV) ## Build php-tools and node-tools images (run after composer.lock / yarn.lock changes)
	@echo "$(BLUE)Building dev images...$(NC)"
	@$(DEV_COMPOSE) build php-tools node-tools
	@echo "$(YELLOW)Note: also run 'make dev-down' to discard old vendor/node_modules volumes.$(NC)"

dev-down: $(DOCKER_ENV) ## Stop dev containers and remove anonymous volumes (clears test DB stamp)
	@$(DEV_COMPOSE) down -v
	@rm -f $(TEST_DB_STAMP)

deps: ## Sandbox only: composer + yarn install (run after composer.lock / yarn.lock changes)
ifdef ORANGEHRM_SANDBOX
	@composer install -d src --no-interaction
	@composer install -d devTools/core --no-interaction
	@for d in src/client installer/client src/test/functional; do (cd $$d && yarn install --immutable) || exit 1; done
else
	@echo "$(YELLOW)On the host, deps live in the images: make build-dev-images && make dev-down$(NC)"
	@exit 1
endif

# Sandbox: install deps on first use and after lock file changes (vendor/ and
# node_modules/ are git-ignored; on the host the docker/dev volumes shadow them).
%/vendor/autoload.php: %/composer.lock
	@composer install -d $* --no-interaction
	@touch $@

%/node_modules/.yarn-state.yml: %/yarn.lock
	@cd $* && yarn install --immutable
	@touch $@

# Install OrangeHRM into the test DB and create the test fixtures DB.
# Idempotent via a stamp file; cleared on dev-down (tmpfs is wiped anyway).
ifdef ORANGEHRM_SANDBOX
$(TEST_DB_STAMP): $(PHP_DEPS)
	@echo "$(BLUE)Setting up test database (MariaDB on 127.0.0.1)...$(NC)"
	@mysqladmin -uroot -proot -h127.0.0.1 ping --silent
	@mysql -uroot -proot -h127.0.0.1 -e 'DROP DATABASE IF EXISTS orangehrm_mysql'
	@rm -f lib/confs/Conf.php
	@rm -rf lib/confs/cryptokeys
	@php installer/cli_install.php
	@php devTools/core/console.php i:create-test-db -p root
	@rm -f $(OTHER_TEST_DB_STAMP)
	@mkdir -p $(dir $(TEST_DB_STAMP))
	@touch $(TEST_DB_STAMP)
	@echo "$(GREEN)Test database ready.$(NC)"
else
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
	@rm -f $(OTHER_TEST_DB_STAMP)
	@mkdir -p $(dir $(TEST_DB_STAMP))
	@touch $(TEST_DB_STAMP)
	@echo "$(GREEN)Test database ready.$(NC)"
endif

test-php: $(TEST_DB_STAMP) ## Run PHPUnit (pass extra flags via ARGS=...)
	@$(PHP_RUN) php -d memory_limit=1G ./src/vendor/bin/phpunit $(ARGS)

test-js: $(JS_DEPS) ## Run Jest unit tests (pass extra flags via ARGS=...)
	@$(NODE_RUN) "cd src/client && yarn test:unit $(ARGS)"

lint: lint-php lint-js ## Run all linters (no fixes)

lint-php: $(PHP_DEPS) ## Check PHP coding standards (matches CI: --php php8.3)
	@$(PHP_RUN) php devTools/core/console.php php-cs-fix --php php8.3

fix-php: $(PHP_DEPS) ## Apply PHP coding-standard fixes on host files
	@$(PHP_RUN) php devTools/core/console.php php-cs-fix --php php8.3

lint-js: $(JS_DEPS) ## Lint all JS workspaces
	@$(NODE_RUN) "cd src/client && yarn lint"
	@$(NODE_RUN) "cd installer/client && yarn lint"
	@$(NODE_RUN) "cd src/test/functional && yarn lint"

fix-js: $(JS_DEPS) ## Apply ESLint --fix in all JS workspaces (writes to host files)
	@$(NODE_RUN) "cd src/client && yarn lint --fix"
	@$(NODE_RUN) "cd installer/client && yarn lint --fix"
	@$(NODE_RUN) "cd src/test/functional && yarn lint --fix"

shell-php: $(DOCKER_ENV) ## Interactive shell in php-tools
	@$(DEV_COMPOSE) run --rm php-tools bash

shell-js: $(DOCKER_ENV) ## Interactive shell in node-tools
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

# ---------------------------------------------------------------------------
# Claude Code in a Docker Sandbox (sbx microVM with its own Docker Engine)
# ---------------------------------------------------------------------------

# sbx builds the local kit with the host's docker buildx and needs an OCI
# exporter, which the default "docker" driver lacks (unless the containerd
# image store is on). Use a dedicated docker-container builder for it.
SBX_BUILDER := sbx-kits

sandbox: ## Start or attach to the Claude Code sandbox defined in sbxenv.yaml
	@docker buildx inspect $(SBX_BUILDER) > /dev/null 2>&1 \
		|| docker buildx create --name $(SBX_BUILDER) --driver docker-container > /dev/null
	@BUILDX_BUILDER=$(SBX_BUILDER) sbx env run

sandbox-rm: ## Remove the sandbox VM (incl. images built inside it)
	@sbx env rm
