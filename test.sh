#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR=${BUILD_DIR:-build}

if [[ ! -d "${BUILD_DIR}" ]]; then
  echo "[test] Build directory '${BUILD_DIR}' not found. Run scripts/build.sh first." >&2
  exit 2
fi

echo "[test] Running ctest in ${BUILD_DIR}..."
ctest --test-dir "${BUILD_DIR}" --output-on-failure

