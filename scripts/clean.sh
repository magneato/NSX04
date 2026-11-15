#!/usr/bin/env bash
set -euo pipefail

COPYRIGHT_NOTICE=${COPYRIGHT_NOTICE:-"Copyright (c) 2025 Robert L. Sitton, Jr. of Neural Splines, LLC - Licensed under AGPL-3.0-or-later"}
echo "${COPYRIGHT_NOTICE}"

echo "[clean] Removing build/ and output/..."
rm -rf build output
echo "[clean] Done."
