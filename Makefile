.PHONY: help new-package add-brew

# ~/.dotiles/Makefile
# 	Local development commands
#   Usage: make <target>
#		Run `make help` to see all available targets

DEV_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))/scripts/dev

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
# Stow / package management
# ---------------------------------------
# new-package: ## Scaffold a new stow package (interactive)
# 	@bash $(DEV_DIR)/new_package.sh

# add-brew: ## Add a new Homebrew package to the Brewfile (interactive)
# 	@bash $(DEV_DIR)/add_brew.sh