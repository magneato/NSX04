#!/usr/bin/env bash
set -euo pipefail

COPYRIGHT_NOTICE=${COPYRIGHT_NOTICE:-"Copyright (c) 2025 Neural Splines, LLC - Licensed under AGPL-3.0-or-later"}
echo "${COPYRIGHT_NOTICE}"

BUILD_DIR=${BUILD_DIR:-build}

echo "[build] Configuring in ${BUILD_DIR}..."
cmake -S . -B "${BUILD_DIR}" -DCMAKE_BUILD_TYPE=Release

echo "[build] Building..."
cmake --build "${BUILD_DIR}" --parallel

echo "[build] Artifacts in ./output (bins/, roms/)"
