#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR"

echo "Building macOS bundle..."
./scripts/build-app.sh

echo "Building Windows binary..."
"$ROOT_DIR/crossplatform/build-windows.sh"
