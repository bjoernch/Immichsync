#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TRIPLE="${1:-x86_64-unknown-windows-msvc}"
BINARY_NAME="ImmichSync"
BUILD_DIR="${ROOT_DIR}/.build/${TRIPLE}/release"
WIN_BINARY="${BUILD_DIR}/${BINARY_NAME}.exe"
DIST_DIR="${ROOT_DIR}/dist/windows"

cd "$ROOT_DIR"

echo "Building Windows release for ${TRIPLE}..."
swift build -c release --triple "$TRIPLE"

if [[ ! -f "$WIN_BINARY" ]]; then
  echo "ERROR: expected Windows binary at $WIN_BINARY" >&2
  exit 1
fi

mkdir -p "$DIST_DIR"
cp "$WIN_BINARY" "$DIST_DIR/${BINARY_NAME}.exe"

echo "Windows binary copied to $DIST_DIR/${BINARY_NAME}.exe"
