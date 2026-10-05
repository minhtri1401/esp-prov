#!/usr/bin/env bash
# Regenerates the Dart protobuf bindings for the vendored Espressif protos.
#
# Requirements:
#   - protoc on PATH (tested with libprotoc 36.2)
#   - protoc_plugin 25.x activated: fvm dart pub global activate protoc_plugin 25.1.0
#   - the FVM link: fvm use 3.47.5 --force
#
# Usage (from the repo root): tool/gen_proto.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROTO_DIR="$ROOT/third_party/espressif/proto"
OUT_DIR="$ROOT/packages/esp_prov_core/lib/src/proto"
PLUGIN="${PROTOC_GEN_DART:-$ROOT/tool/protoc-gen-dart}"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# The .proto files import each other by bare file name, so the proto
# directory itself is the only include path.
protoc \
  --plugin=protoc-gen-dart="$PLUGIN" \
  -I "$PROTO_DIR" \
  --dart_out="$OUT_DIR" \
  constants.proto session.proto sec0.proto sec1.proto sec2.proto \
  network_constants.proto network_config.proto network_scan.proto network_ctrl.proto

# JSON descriptors are unused; drop them to keep the package small.
rm -f "$OUT_DIR"/*.pbjson.dart

# Format with the workspace SDK so `dart format --set-exit-if-changed` passes.
(cd "$ROOT" && fvm dart format "$OUT_DIR" > /dev/null)

echo "Generated $(ls "$OUT_DIR" | wc -l | tr -d ' ') files into packages/esp_prov_core/lib/src/proto"
