#!/usr/bin/env bash
set -euo pipefail

moon build --target js

if command -v python3 >/dev/null 2>&1; then
  echo "Serving on http://localhost:8000 (Ctrl+C to stop)"
  python3 -m http.server 8000
else
  echo "Built JS. Open index.html with a local server."
fi
