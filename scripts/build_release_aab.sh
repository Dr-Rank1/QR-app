#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "Fetching dependencies..."
flutter pub get

echo "Running analyzer and tests..."
flutter analyze
flutter test

echo "Building release Android App Bundle..."
flutter build appbundle --release

OUTPUT="$ROOT/build/app/outputs/bundle/release/app-release.aab"
if [[ -f "$OUTPUT" ]]; then
  echo "AAB ready: $OUTPUT"
else
  echo "AAB build finished but output file was not found at $OUTPUT" >&2
  exit 1
fi
