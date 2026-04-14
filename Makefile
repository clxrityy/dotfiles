.PHONY: help copy-package

# ~/.dotiles/Makefile
# 	Local development commands
#   Usage: make <target>
#		Run `make help` to see all available targets

SCRIPTS_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))/scripts
DEV_DIR := $(SCRIPTS_DIR)/dev
# Args forwarding for script-wrapper targets
SCRIPT_ARG_TARGETS := copy-package migrate-package ssh2-to-openssh install
GOAL_ARGS := $(filter-out --,$(wordlist 2,$(words $(MAKECMDGOALS)), $(MAKECMDGOALS)))

# Allow explicit ARGS="..." to override, otherwise fallback to goal-based args
ARGS ?= $(GOAL_ARGS)

# Swallow extra pseudo-goals only when first goal is a script-wrapper target
ifneq ($(filter $(firstword $(MAKECMDGOALS)),$(SCRIPT_ARG_TARGETS)),)
%:
	@:
endif

# ---------------------------------------
# Self-documenting help target.
# Parses ## comments on each target line.
# ---------------------------------------
help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''

	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
    | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ---------------------------------------
# Make scripts executable
# ---------------------------------------
enable-scripts: ## Make all scripts/ executable
	@find $(SCRIPTS_DIR) -type f -name "*.sh" -exec chmod +x {} \;

# ---------------------------------------
# Installation
# ---------------------------------------
install: enable-scripts ## Install dotfiles
	@bash install.sh ${ARGS}

# ---------------------------------------
# Stow / package management
# ---------------------------------------
copy-package: ## Copy package files to target location (usage: make copy-package <package_name>)
	@${DEV_DIR}/copy-package.sh ${ARGS}

migrate-package: ## Migrate package to new name/scope (usage: make migrate-package <current_package> <new_package> <target_spec>)
	@${DEV_DIR}/migrate-package.sh ${ARGS}

# ---------------------------------------
# USB / Ventoy setup
# ---------------------------------------
ventoy: ## Setup Ventoy USB on external drive (support for macOS/Linux)
	@${SCRIPTS_DIR}/extra/ventoy.sh

# ---------------------------------------
# macOS STUN block
# ---------------------------------------
stun-block: ## Block STUN traffic (macOS only)
	@${SCRIPTS_DIR}/extra/macos-stun-block.sh

# ---------------------------------------
# Convert SSH2 keys to OpenSSH format
# ---------------------------------------
ssh2-to-openssh: ## Convert SSH2 private keys to OpenSSH format (usage: make ssh2-to-openssh <keyfile>)
	@${SCRIPTS_DIR}/extra/ssh2-to-openssh.sh ${ARGS}

# ---------------------------------------
# Testing
# ---------------------------------------
test: ## Run all tests
	@bash $(SCRIPTS_DIR)/tests/run