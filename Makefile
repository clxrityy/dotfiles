.PHONY: help copy-package

# ~/.dotiles/Makefile
# 	Local development commands
#   Usage: make <target>
#		Run `make help` to see all available targets

SCRIPTS_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))/scripts
DEV_DIR := $(SCRIPTS_DIR)/dev
ARGS := $(wordlist 2, $(words $(MAKECMDGOALS)), $(MAKECMDGOALS))

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
install: ## Install dotfiles
	bash install.sh

# ---------------------------------------
# Stow / package management
# ---------------------------------------
copy-package: ## Copy package files to target location (usage: make copy-package <package_name>)
	@${DEV_DIR}/copy-package.sh ${ARGS}

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