.PHONY: help install install-php install-node test test-php test-php-coverage test-node test-node-coverage lint lint-php lint-php-fix lint-node lint-node-installer build build-client build-installer db-up db-down db-install db-reset shell-php shell-node clean

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m # No Color

# Docker Compose command
COMPOSE := docker-compose -f docker-compose.dev.yml

# Check if .env exists, if not create it from example
.env:
	@if [ ! -f .env ]; then \
		echo "$(YELLOW)Creating .env file from .env.dev.example...$(NC)"; \
		if [ -f .env.dev.example ]; then \
			cp .env.dev.example .env; \
			echo "UID=$$(id -u)" >> .env; \
			echo "GID=$$(id -g)" >> .env; \
			echo "$(GREEN).env file created with your UID/GID$(NC)"; \
		else \
			echo "UID=$$(id -u)" > .env; \
			echo "GID=$$(id -g)" >> .env; \
			echo "XDEBUG_MODE=off" >> .env; \
			echo "$(GREEN).env file created$(NC)"; \
		fi; \
	fi

# Default target - show help
help: ## Show this help message
	@echo "$(BLUE)OrangeHRM Development Environment$(NC)"
	@echo ""
	@echo "$(GREEN)Available commands:$(NC)"
	@awk 'BEGIN {FS = ":.*##"; printf "\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(BLUE)%-20s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(YELLOW)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@echo ""

##@ Setup & Installation

install: .env install-php install-node ## Install all dependencies (PHP + Node)
	@echo "$(GREEN)All dependencies installed successfully!$(NC)"

install-php: .env ## Install PHP dependencies with Composer
	@echo "$(BLUE)Installing PHP dependencies...$(NC)"
	@$(COMPOSE) run --rm php-test composer install -d src
	@$(COMPOSE) run --rm php-test composer install -d devTools/core
	@echo "$(GREEN)PHP dependencies installed!$(NC)"

install-node: .env ## Install Node dependencies with Yarn
	@echo "$(BLUE)Installing Node dependencies...$(NC)"
	@$(COMPOSE) run --rm node-test bash -c "cd src/client && yarn install"
	@$(COMPOSE) run --rm node-test bash -c "cd installer/client && yarn install"
	@$(COMPOSE) run --rm node-test bash -c "cd src/test/functional && yarn install"
	@echo "$(GREEN)Node dependencies installed!$(NC)"

##@ Testing

test: test-php test-node ## Run all tests (PHPUnit + Jest)

test-php: .env ## Run PHPUnit tests
	@echo "$(BLUE)Running PHPUnit tests...$(NC)"
	@$(COMPOSE) run --rm php-test ./src/vendor/bin/phpunit

test-php-coverage: .env ## Run PHPUnit tests with coverage
	@echo "$(BLUE)Running PHPUnit tests with coverage...$(NC)"
	@$(COMPOSE) run --rm -e XDEBUG_MODE=coverage php-test ./src/vendor/bin/phpunit --coverage-html coverage -d memory_limit=1G
	@echo "$(GREEN)Coverage report generated in coverage/$(NC)"

test-node: .env ## Run Jest tests (Vue unit tests)
	@echo "$(BLUE)Running Jest tests...$(NC)"
	@$(COMPOSE) run --rm node-test bash -c "cd src/client && yarn test:unit"

test-node-coverage: .env ## Run Jest tests with coverage
	@echo "$(BLUE)Running Jest tests with coverage...$(NC)"
	@$(COMPOSE) run --rm node-test bash -c "cd src/client && yarn test:unit --coverage"
	@echo "$(GREEN)Coverage report generated in src/client/coverage/$(NC)"

##@ Linting

lint: lint-php lint-node ## Run all linters (PHP + Node)

lint-php: .env ## Check PHP coding standards (read-only)
	@echo "$(BLUE)Checking PHP coding standards...$(NC)"
	@$(COMPOSE) run --rm php-test php devTools/core/console.php php-cs-fix --php php

lint-php-fix: .env ## Fix PHP coding standards
	@echo "$(BLUE)Fixing PHP coding standards...$(NC)"
	@$(COMPOSE) run --rm php-test php devTools/core/console.php php-cs-fix --php php --fix
	@echo "$(GREEN)PHP coding standards fixed!$(NC)"

lint-node: .env ## Check Node/Vue code with ESLint
	@echo "$(BLUE)Linting client code...$(NC)"
	@$(COMPOSE) run --rm node-test bash -c "cd src/client && yarn lint"
	@echo "$(BLUE)Linting installer code...$(NC)"
	@$(COMPOSE) run --rm node-test bash -c "cd installer/client && yarn lint"
	@echo "$(BLUE)Linting Cypress tests...$(NC)"
	@$(COMPOSE) run --rm node-test bash -c "cd src/test/functional && yarn lint"

lint-node-installer: .env ## Check installer code with ESLint
	@echo "$(BLUE)Linting installer code...$(NC)"
	@$(COMPOSE) run --rm node-test bash -c "cd installer/client && yarn lint"

##@ Building

build: .env ## Full OrangeHRM build (like CI)
	@echo "$(BLUE)Running full build...$(NC)"
	@$(COMPOSE) run --rm node-test bash -c "cd src/client && yarn build"
	@$(COMPOSE) run --rm node-test bash -c "cd installer/client && yarn build"
	@echo "$(GREEN)Build completed!$(NC)"

build-client: .env ## Build Vue client only
	@echo "$(BLUE)Building Vue client...$(NC)"
	@$(COMPOSE) run --rm node-test bash -c "cd src/client && yarn build"
	@echo "$(GREEN)Client built!$(NC)"

build-installer: .env ## Build installer client only
	@echo "$(BLUE)Building installer client...$(NC)"
	@$(COMPOSE) run --rm node-test bash -c "cd installer/client && yarn build"
	@echo "$(GREEN)Installer built!$(NC)"

##@ Database

db-up: .env ## Start MariaDB container
	@echo "$(BLUE)Starting MariaDB...$(NC)"
	@$(COMPOSE) up -d mariadb-test
	@echo "$(GREEN)MariaDB started! Waiting for health check...$(NC)"
	@$(COMPOSE) exec mariadb-test mysqladmin ping -h localhost -proot --wait=30 && echo "$(GREEN)MariaDB is ready!$(NC)" || echo "$(YELLOW)MariaDB might still be starting...$(NC)"

db-down: .env ## Stop MariaDB container
	@echo "$(BLUE)Stopping MariaDB...$(NC)"
	@$(COMPOSE) down mariadb-test
	@echo "$(GREEN)MariaDB stopped!$(NC)"

db-install: .env ## Install OrangeHRM via CLI
	@echo "$(BLUE)Installing OrangeHRM...$(NC)"
	@$(COMPOSE) run --rm php-test php installer/cli_install.php
	@echo "$(GREEN)OrangeHRM installed!$(NC)"

db-reset: .env ## Reset OrangeHRM installation
	@echo "$(BLUE)Resetting OrangeHRM installation...$(NC)"
	@$(COMPOSE) run --rm php-test php devTools/core/console.php i:reset
	@echo "$(GREEN)Database reset!$(NC)"

##@ Development

shell-php: .env ## Open interactive PHP shell
	@echo "$(BLUE)Opening PHP shell...$(NC)"
	@$(COMPOSE) run --rm php-test bash

shell-node: .env ## Open interactive Node shell
	@echo "$(BLUE)Opening Node shell...$(NC)"
	@$(COMPOSE) run --rm node-test bash

clean: ## Clean generated files and caches
	@echo "$(BLUE)Cleaning generated files...$(NC)"
	@rm -rf coverage/
	@rm -rf src/client/coverage/
	@rm -rf src/client/node_modules/
	@rm -rf installer/client/node_modules/
	@rm -rf src/test/functional/node_modules/
	@rm -rf src/vendor/
	@rm -rf devTools/core/vendor/
	@echo "$(GREEN)Cleanup completed!$(NC)"

##@ Docker Management

docker-build: .env ## Build Docker images
	@echo "$(BLUE)Building Docker images...$(NC)"
	@$(COMPOSE) build
	@echo "$(GREEN)Docker images built!$(NC)"

docker-clean: ## Remove all containers and volumes
	@echo "$(YELLOW)Removing all containers and volumes...$(NC)"
	@$(COMPOSE) down -v
	@echo "$(GREEN)Cleanup completed!$(NC)"
