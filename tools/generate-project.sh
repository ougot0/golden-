#!/usr/bin/env bash
# Regenerates GoldenHour.xcodeproj from project.yml.
# macOS: brew install xcodegen && ./tools/generate-project.sh
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate
