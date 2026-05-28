#!/usr/bin/env bash
# debian/install.sh
#
# Purpose:
#   Debian-specific installer
#   this script is called by the main install.sh script when it detects that the system is running Debian
#
# Responsibilities:
#   - Install necessary dependencies using apt
#   - Set up any Debian-specific configurations if needed

set -euo pipefail

echo "Installing dependencies for Debian..."

# Update package lists
sudo apt update
# Install utilities
# - installing rust/cargo & adding to PATH
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source $HOME/.cargo/env
# - installing fastfetch
sudo apt install -y fastfetch
# - installing htop
sudo apt install -y htop
# - installing zsh
sudo apt install -y zsh

# Installing bonds (a tool for managing symlinks) with cargo
# Note: This assumes that the user has Rust and Cargo installed, which is handled in the previous step
# SEE: https://bonds.fyi/
echo "Installing bonds (a tool for managing symlinks) with cargo..."
cargo install bonds-cli
