#!/usr/bin/env bash
# Format check, static analysis and tests for every workspace package.
# Local: tool/check.sh   CI: FLUTTER=flutter DART=dart tool/check.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER="${FLUTTER:-fvm flutter}"
DART="${DART:-fvm dart}"
PACKAGES=(
  packages/esp_prov_core
  packages/esp_prov_ble_universal
  packages/esp_prov
  packages/esp_prov/example
)

cd "$ROOT"
$FLUTTER pub get
$DART format --output=none --set-exit-if-changed packages

for pkg in "${PACKAGES[@]}"; do
  [[ -f "$pkg/pubspec.yaml" ]] || continue
  echo "== $pkg"
  if grep -q "sdk: flutter" "$pkg/pubspec.yaml"; then
    (cd "$pkg" && $FLUTTER analyze --fatal-infos)
    if [[ -d "$pkg/test" ]]; then (cd "$pkg" && $FLUTTER test); fi
  else
    (cd "$pkg" && $DART analyze --fatal-infos)
    (cd "$pkg" && $DART test)
  fi
done
echo "All checks passed."
