#!/usr/bin/env bash
set -euo pipefail

COPYRIGHT_NOTICE=${COPYRIGHT_NOTICE:-"Copyright (c) 2025 Neural Splines, LLC - Licensed under AGPL-3.0-or-later"}
echo "${COPYRIGHT_NOTICE}"

BUILD_DIR=${BUILD_DIR:-build}

if [[ ! -d "${BUILD_DIR}" ]]; then
  echo "[test] Build directory '${BUILD_DIR}' not found. Run scripts/build.sh first." >&2
  exit 2
fi

echo "[test] Running ctest in ${BUILD_DIR}..."
ctest --test-dir "${BUILD_DIR}" --output-on-failure
