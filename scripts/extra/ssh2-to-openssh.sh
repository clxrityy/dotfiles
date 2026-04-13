#!/bin/bash
# ----------
# Convert SSH2 private key to OpenSSH format
#   << Uses Puttygen to convert SSH2 private key to OpenSSH format
#   |- Usage: ./ssh2-to-openssh.sh <input-ssh2-key>
#   |-- Example: ./ssh2-to-openssh.sh ~/.ssh/id_rsa.ppk
# ----------

# ====
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
SCRIPTS_DIR="$REPO_DIR/scripts"

# shellcheck source=/dev/null
source "$SCRIPTS_DIR/source.sh"

if [ "$#" -ne 1 ]; then
  log_error "Usage: $0 <input-ssh2-key>"
  exit 1
fi

# ====
input_key="$1"


validate_private_key() {
  if ! openssl rsa -in "$input_key" -check -noout >/dev/null 2>&1; then # Check if it's a valid RSA private key
    log_error "Invalid SSH2 private key: $input_key"
    exit 1
  fi
}

check_for_puttygen() {
  if ! command -v puttygen >/dev/null 2>&1; then
    log_error "puttygen is not installed. Please install it to use this script."
    exit 1
  fi
}

convert_key() {
  local output_key="${input_key%.*}" # Remove file extension for output key (e.g., id_rsa.ppk -> id_rsa)
  if puttygen "$input_key" -O private-openssh -o "$output_key"; then
    log_success "Successfully converted SSH2 key to OpenSSH format: $output_key"
  else
    log_error "Failed to convert SSH2 key: $input_key"
    exit 1
  fi

  chmod 600 "$output_key"
  log_info "Set permissions to 600 for the converted key: $output_key"
}
