#!/usr/bin/env bash
set -euo pipefail

COPYRIGHT_NOTICE=${COPYRIGHT_NOTICE:-"Copyright (c) 2025 Neural Splines, LLC - Licensed under AGPL-3.0-or-later"}
echo "${COPYRIGHT_NOTICE}"

echo "[setup] Updating package lists..."
sudo apt-get update -y

echo "[setup] Installing build tools (cmake, build-essential, nasm)..."
sudo apt-get install -y cmake build-essential nasm

echo "[setup] Done."
