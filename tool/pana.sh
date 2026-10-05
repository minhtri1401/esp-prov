#!/usr/bin/env bash
# Scores one workspace package with pana the way pub.dev sees it: the
# package directory alone, with `resolution: workspace` removed so its
# dependencies resolve from pub.dev.
#
# Requirements: fvm dart pub global activate pana
# Usage: tool/pana.sh packages/esp_prov_core
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG="${1:?usage: tool/pana.sh packages/<name>}"
NAME="$(basename "$PKG")"
SDK="$ROOT/.fvm/flutter_sdk"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cp -R "$ROOT/$PKG" "$TMP/$NAME"
rm -rf "$TMP/$NAME/.dart_tool" "$TMP/$NAME/build"
sed -i.bak '/^resolution: workspace$/d' "$TMP/$NAME/pubspec.yaml"
rm "$TMP/$NAME/pubspec.yaml.bak"

PATH="$SDK/bin:$PATH" "$SDK/bin/dart" pub global run pana \
  --no-warning --flutter-sdk "$SDK" "$TMP/$NAME"
