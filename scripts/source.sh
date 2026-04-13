#!/bin/bash

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPTS_DIR/lib/colors.sh"
init_colors
# shellcheck source=/dev/null
source "$SCRIPTS_DIR/lib/log.sh"
# shellcheck source=/dev/null
source "$SCRIPTS_DIR/lib/banner.sh"
# shellcheck source=/dev/null
source "$SCRIPTS_DIR/lib/prompt.sh"
