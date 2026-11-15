#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" == "clean" ]]; then
  exec bash "${SCRIPT_DIR}/scripts/clean.sh"
fi

exec bash "${SCRIPT_DIR}/scripts/build.sh" "$@"
