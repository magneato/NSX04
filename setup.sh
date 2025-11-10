#!/usr/bin/env bash
set -euo pipefail

echo "[setup] Updating package lists..."
sudo apt-get update -y

echo "[setup] Installing build tools (cmake, build-essential, nasm)..."
sudo apt-get install -y cmake build-essential nasm

echo "[setup] Done."

