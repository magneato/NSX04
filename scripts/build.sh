#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR=${BUILD_DIR:-build}

echo "[build] Configuring in ${BUILD_DIR}..."
cmake -S . -B "${BUILD_DIR}" -DCMAKE_BUILD_TYPE=Release

echo "[build] Building..."
cmake --build "${BUILD_DIR}" --parallel

echo "[build] Artifacts in ./output (bins/, roms/)"
