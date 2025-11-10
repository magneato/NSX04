#!/usr/bin/env bash
set -euo pipefail

COPYRIGHT_NOTICE=${COPYRIGHT_NOTICE:-"Copyright (c) 2025 Neural Splines, LLC - Licensed under AGPL-3.0-or-later"}
echo "${COPYRIGHT_NOTICE}"

echo "[clean] Removing build/ and out/..."
rm -rf build out
echo "[clean] Done."
