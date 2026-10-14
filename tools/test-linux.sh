#!/usr/bin/env bash
# Runs the GoldenHourKit package tests (solar engine + core logic) on Linux inside the
# official Swift Docker image. Useful for CI or for machines without Xcode.
# On macOS you can simply run: swift test --package-path Packages/GoldenHourKit
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${SWIFT_IMAGE:-swift:6.0.3-noble}"
docker run --rm -v "$ROOT/Packages/GoldenHourKit:/pkg" -w /pkg "$IMAGE" \
  bash -c "swift build --build-path /tmp/.build && swift test --build-path /tmp/.build $*"
