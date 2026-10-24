#!/usr/bin/env bash
# Export the same Release variant as production, with opt-in pre-engine diagnostics.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/web
"${GODOT:-godot}" --headless --path . --export-release Web build/web/index.html
cp web/startup_diagnostics.js build/web/startup_diagnostics.js
cp web/input-probe.html build/web/input-probe.html
cp docs/google-tv-input.md build/web/DIAGNOSTICA.md
