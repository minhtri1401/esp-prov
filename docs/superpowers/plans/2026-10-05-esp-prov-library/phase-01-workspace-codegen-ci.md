> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

Part of the [esp_prov Library Implementation Plan](plan.md). Before any task,
read that file's **Global Constraints** (toolchain, `fvm` commands, names,
lint rules, commit trailers) and **Review Focus**. Spec:
`docs/superpowers/specs/2026-10-05-esp-prov-library-design.md`.

# Phase 1: Workspace scaffold, vendored protos, codegen, CI

**Goal:** A pub workspace on the pinned toolchain with committed Dart protobuf bindings for the Espressif protos, a one-command local check, and CI.

**Depends on:** nothing.

---

### Task 1.1: Toolchain pin, workspace skeleton and generated protobuf bindings

**Files:**
- Create: `third_party/espressif/proto/*.proto, LICENSE.esp-idf, LICENSE.network_provisioning` (downloaded, unmodified)
- Create: `packages/esp_prov_core/lib/src/proto/*.pb.dart, *.pbenum.dart` (generated, committed)
- Create: `.fvmrc`
- Create: `.gitignore`
- Create: `pubspec.yaml`
- Create: `analysis_options.yaml`
- Create: `packages/esp_prov_core/pubspec.yaml`
- Create: `packages/esp_prov_core/analysis_options.yaml`
- Create: `packages/esp_prov_core/lib/esp_prov_core.dart`
- Create: `third_party/espressif/proto/README.md`
- Create: `tool/protoc-gen-dart`
- Create: `tool/gen_proto.sh`
- Test: `packages/esp_prov_core/test/proto/proto_bindings_test.dart`

**Interfaces:**
- Consumes: nothing (the repo only contains `docs/`).
- Produces: pub workspace rooted at `pubspec.yaml` with member
`packages/esp_prov_core`; generated bindings importable as
`package:esp_prov_core/src/proto/<name>.pb.dart` (always imported with the
prefix `pb` in library code). Generated names used later, verbatim from the
protos: `SessionData` (oneof getter `whichProto()` returning
`SessionData_Proto.sec0|sec1|sec2|notSet`), `SecSchemeVersion.SecScheme0..2`,
`Status.Success..InvalidSession`, `Sec0Payload`/`S0SessionCmd`/`S0SessionResp`,
`Sec1Payload`/`SessionCmd0`/`SessionResp0`/`SessionCmd1`/`SessionResp1`
(fields `clientPubkey`, `devicePubkey`, `deviceRandom`, `clientVerifyData`,
`deviceVerifyData`), `Sec2Payload`/`S2SessionCmd0`/`S2SessionResp0`/
`S2SessionCmd1`/`S2SessionResp1` (fields `clientUsername`, `clientPubkey`,
`devicePubkey`, `deviceSalt`, `clientProof`, `deviceProof`, `deviceNonce`),
`NetworkScanPayload`, `NetworkConfigPayload`, `NetworkCtrlPayload`,
`WifiStationState.Connected|Connecting|Disconnected|ConnectionFailed`,
`WifiConnectFailedReason.AuthError|WifiNetworkNotFound`,
`ThreadNetworkState.Attached|Attaching|Dettached|AttachingFailed`,
`ThreadAttachFailedReason.DatasetInvalid|ThreadNetworkNotFound`. Scripts:
`tool/gen_proto.sh`, `tool/protoc-gen-dart`.

Background for the implementer: Espressif's protocomm protocol carries
protobuf messages. We vendor the `.proto` files at pinned commits and commit
the generated Dart. The protos import each other by bare file name
(`import "constants.proto";`), so `protoc` gets exactly one include path,
the vendored directory. `protoc_plugin` 25.x needs `protobuf` ^6.1.

FVM note: the Mac has FVM 2.4.1, which ignores `.fvmrc` and keys off
`.fvm/fvm_config.json`. `fvm use 3.47.5 --force` creates that (gitignored)
link; `.fvmrc` is committed for FVM 3 users and tools.

- [ ] **Step 1: Pin the toolchain**

Create `.fvmrc`:

```json
{"flutter": "3.47.5"}
```

Create `.gitignore`:

```text
.dart_tool/
build/
.fvm/
.venv/
.cache/
pubspec_overrides.yaml
*.iml
.idea/
.DS_Store
coverage/
```

Run: `fvm use 3.47.5 --force && fvm dart --version && fvm flutter --version`

Expected: `Dart SDK version: 3.13.4 (stable)` and `Flutter 3.47.5 • channel stable`.

If `fvm use` reports the version is not installed, run `fvm install 3.47.5` first.

- [ ] **Step 2: Create the workspace root and the core package skeleton**

The package-level `analysis_options.yaml` files are self-contained
(they do not include `../../analysis_options.yaml`) because only the package
directory is published, and pana scores the published copy.

Create `pubspec.yaml`:

```yaml
name: esp_prov_workspace
publish_to: none

environment:
  sdk: ^3.13.0

workspace:
  - packages/esp_prov_core

dev_dependencies:
  very_good_analysis: ^11.0.0
```

Create `analysis_options.yaml`:

```yaml
include: package:very_good_analysis/analysis_options.yaml
```

Create `packages/esp_prov_core/pubspec.yaml`:

```yaml
name: esp_prov_core
description: >-
  Pure-Dart client for Espressif Unified Provisioning (protocomm): Security 0,
  1 and 2, Wi-Fi and Thread provisioning flows and custom endpoints.
version: 0.1.0
repository: https://github.com/MinhTri1401/esp_prov/tree/main/packages/esp_prov_core
issue_tracker: https://github.com/MinhTri1401/esp_prov/issues
topics:
  - esp32
  - provisioning
  - wifi
  - iot
  - bluetooth

resolution: workspace

environment:
  sdk: ^3.13.0

dependencies:
  crypto: ^3.0.7
  cryptography_plus: ^3.0.0
  meta: ^1.16.0
  protobuf: ^6.1.0

dev_dependencies:
  test: ^1.25.0
  very_good_analysis: ^11.0.0
```

Create `packages/esp_prov_core/analysis_options.yaml`:

```yaml
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  exclude:
    - lib/src/proto/**
```

Create `packages/esp_prov_core/lib/esp_prov_core.dart`:

```dart
/// Pure-Dart client for Espressif Unified Provisioning (protocomm).
///
/// Bring a `ProvTransport` (for example from `esp_prov_ble_universal`), open
/// an `EspSession`, then use its Wi-Fi, Thread, control and custom endpoint
/// flows.
library;
```

Run: `fvm dart pub get`

Expected: `Got dependencies!` and a single `pubspec.lock` at the repository root (none inside `packages/esp_prov_core`).

- [ ] **Step 3: Write the failing binding test**

The byte list in the second test pins the `network_provisioning` field numbers (Thread fields 16-21), so a vendoring mistake fails loudly.

Create `packages/esp_prov_core/test/proto/proto_bindings_test.dart`:

```dart
import 'package:esp_prov_core/src/proto/constants.pb.dart';
import 'package:esp_prov_core/src/proto/network_config.pb.dart';
import 'package:esp_prov_core/src/proto/network_constants.pb.dart';
import 'package:esp_prov_core/src/proto/sec1.pb.dart';
import 'package:esp_prov_core/src/proto/session.pb.dart';
import 'package:test/test.dart';

void main() {
  test('SessionData round-trips through bytes', () {
    final original = SessionData(
      secVer: SecSchemeVersion.SecScheme1,
      sec1: Sec1Payload(
        msg: Sec1MsgType.Session_Command1,
        sc1: SessionCmd1(clientVerifyData: [1, 2, 3]),
      ),
    );
    final decoded = SessionData.fromBuffer(original.writeToBuffer());
    expect(decoded.whichProto(), SessionData_Proto.sec1);
    expect(decoded.sec1.sc1.clientVerifyData, [1, 2, 3]);
  });

  test('Thread messages use the network_provisioning field numbers', () {
    final bytes = NetworkConfigPayload(
      msg: NetworkConfigMsgType.TypeCmdSetThreadConfig,
      cmdSetThreadConfig: CmdSetThreadConfig(dataset: [1]),
    ).writeToBuffer();
    // msg = 8 (field 1), cmd_set_thread_config = field 18 holding dataset [1].
    expect(bytes, [0x08, 0x08, 0x92, 0x01, 0x03, 0x0a, 0x01, 0x01]);
  });

  test('enum names are verbatim from the Espressif protos', () {
    expect(Status.InvalidSession.value, 7);
    expect(WifiConnectFailedReason.WifiNetworkNotFound.value, 1);
    expect(ThreadNetworkState.Dettached.value, 2);
    expect(WifiAuthMode.WPA2_WPA3_PSK.value, 7);
  });
}
```

- [ ] **Step 4: Run it to verify it fails**

Run: `(cd packages/esp_prov_core && fvm dart test test/proto/proto_bindings_test.dart)`

Expected: FAIL: compilation error `Error when reading 'lib/src/proto/constants.pb.dart': No such file or directory`.

- [ ] **Step 5: Vendor the Espressif protos and licenses at pinned commits**

Create `third_party/espressif/proto/README.md`:

```markdown
# Vendored Espressif protobuf definitions

These `.proto` files are copied unmodified from Espressif repositories and
compiled into `packages/esp_prov_core/lib/src/proto` by `tool/gen_proto.sh`.
They import each other by bare file name, so `protoc` runs with this
directory as its only include path.

| File | Source repository | Path | Commit |
|---|---|---|---|
| constants.proto, session.proto, sec0.proto, sec1.proto, sec2.proto | [espressif/esp-idf](https://github.com/espressif/esp-idf) | `components/protocomm/proto/` | `4d59230ddff16327812782151ef0afef202dc6d7` (master, 2026-09-25) |
| network_constants.proto, network_config.proto, network_scan.proto, network_ctrl.proto | [espressif/idf-extra-components](https://github.com/espressif/idf-extra-components) | `network_provisioning/proto/` | `69e8b21e1a20c8c1c48f5d5cffceeb0bc262eed0` (master, 2026-10-02) |

The `network_*` messages are wire compatible with the older
`wifi_provisioning` `wifi_*.proto` files (same field numbers) and add the
Thread messages (enum values 6-11, payload fields 16-21).

Licenses: both sources are Apache-2.0. See `LICENSE.esp-idf` and
`LICENSE.network_provisioning` in this directory.

To update: change the commits in this table and in `tool/gen_fixtures.py`,
re-download the files with the commands in
`docs/superpowers/plans/2026-10-05-esp-prov-library/phase-01-workspace-codegen-ci.md`
(Task 1.1, Step 5), run `tool/gen_proto.sh`, then `tool/check.sh`.
```

Run (from the repository root):

```bash
IDF=4d59230ddff16327812782151ef0afef202dc6d7
IEC=69e8b21e1a20c8c1c48f5d5cffceeb0bc262eed0
P=third_party/espressif/proto
mkdir -p "$P"
for f in constants session sec0 sec1 sec2; do
  curl -fsSL -o "$P/$f.proto" \
    "https://raw.githubusercontent.com/espressif/esp-idf/$IDF/components/protocomm/proto/$f.proto"
done
for f in network_constants network_config network_scan network_ctrl; do
  curl -fsSL -o "$P/$f.proto" \
    "https://raw.githubusercontent.com/espressif/idf-extra-components/$IEC/network_provisioning/proto/$f.proto"
done
curl -fsSL -o "$P/LICENSE.esp-idf" \
  "https://raw.githubusercontent.com/espressif/esp-idf/$IDF/LICENSE"
curl -fsSL -o "$P/LICENSE.network_provisioning" \
  "https://raw.githubusercontent.com/espressif/idf-extra-components/$IEC/network_provisioning/LICENSE"
ls "$P"
```

Expected: 11 files listed (9 `.proto`, 2 `LICENSE.*`) plus `README.md`. `grep -c WifiNetworkNotFound third_party/espressif/proto/network_constants.proto` prints `1`.

- [ ] **Step 6: Add the code generator scripts**

Create `tool/protoc-gen-dart`:

```bash
#!/usr/bin/env sh
# protoc plugin shim used by tool/gen_proto.sh.
#
# Runs the globally activated protoc_plugin (25.x) with the FVM-pinned Dart
# SDK. It calls the SDK binary directly because `fvm dart` does not forward
# stdin, and protoc talks to plugins over stdin/stdout.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DART="$ROOT/.fvm/flutter_sdk/bin/dart"
if [ ! -x "$DART" ]; then
  echo "Pinned SDK not found at $DART. Run: fvm use 3.47.5 --force" >&2
  exit 1
fi
exec "$DART" pub global run protoc_plugin:protoc_plugin "$@"
```

Create `tool/gen_proto.sh`:

```bash
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
```

Run: `chmod +x tool/protoc-gen-dart tool/gen_proto.sh && protoc --version`

Expected: `libprotoc 36.2` (this Mac; any recent protoc with proto3 support works).

- [ ] **Step 7: Activate protoc_plugin 25.1.0 and generate**

Run: `fvm dart pub global activate protoc_plugin 25.1.0 && tool/gen_proto.sh`

Expected: `Activated protoc_plugin 25.1.0.` then `Generated 18 files into packages/esp_prov_core/lib/src/proto` (a `.pb.dart` and `.pbenum.dart` per proto).

Activation replaces any globally activated protoc_plugin (this Mac had
21.1.0). `tool/protoc-gen-dart` runs it with the pinned SDK, so the
`dart` that happens to be first on PATH (Homebrew Dart 3.6.0 here) does
not matter.

- [ ] **Step 8: Run the test to verify it passes**

Run: `(cd packages/esp_prov_core && fvm dart test test/proto/proto_bindings_test.dart)`

Expected: `+3: All tests passed!`

- [ ] **Step 9: Analyze and check formatting**

Run: `(cd packages/esp_prov_core && fvm dart analyze --fatal-infos) && fvm dart format --output=none --set-exit-if-changed packages`

Expected: `No issues found!` and `Formatted N files (0 changed)`. Generated code is excluded from analysis by `lib/src/proto/**` in the package options.

- [ ] **Step 10: Commit**

```bash
git add \
  .fvmrc \
  .gitignore \
  pubspec.yaml \
  analysis_options.yaml \
  packages/esp_prov_core/pubspec.yaml \
  packages/esp_prov_core/analysis_options.yaml \
  packages/esp_prov_core/lib/esp_prov_core.dart \
  packages/esp_prov_core/test/proto/proto_bindings_test.dart \
  third_party/espressif/proto/README.md \
  tool/protoc-gen-dart \
  tool/gen_proto.sh \
  pubspec.lock \
  third_party/espressif/proto/constants.proto \
  third_party/espressif/proto/session.proto \
  third_party/espressif/proto/sec0.proto \
  third_party/espressif/proto/sec1.proto \
  third_party/espressif/proto/sec2.proto \
  third_party/espressif/proto/network_constants.proto \
  third_party/espressif/proto/network_config.proto \
  third_party/espressif/proto/network_scan.proto \
  third_party/espressif/proto/network_ctrl.proto \
  third_party/espressif/proto/LICENSE.esp-idf \
  third_party/espressif/proto/LICENSE.network_provisioning \
  packages/esp_prov_core/lib/src/proto
git commit -m "build: pub workspace, vendored Espressif protos and Dart bindings" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014gxDHNxF3eTEzoig5VhMXn"
```

---

### Task 1.2: One-command check script and CI

**Files:**
- Create: `tool/check.sh`
- Create: `.github/workflows/ci.yaml`

**Interfaces:**
- Consumes: workspace from Task 1.1.
- Produces: `tool/check.sh` (pub get, `dart format --set-exit-if-changed`, `analyze
--fatal-infos` and tests for every workspace package that exists; uses
`fvm flutter`/`fvm dart` locally, plain `flutter`/`dart` in CI via the
`FLUTTER`/`DART` env vars). Later phases rely on it and on CI picking up new
packages without edits.

- [ ] **Step 1: Write the check script**

It lists all four packages up front and skips any that do not exist yet, so later phases never edit it. Flutter packages are detected by `sdk: flutter` in their pubspec.

Create `tool/check.sh`:

```bash
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
```

- [ ] **Step 2: Run it**

Run: `chmod +x tool/check.sh && tool/check.sh`

Expected: `== packages/esp_prov_core`, `No issues found!`, `All tests passed!`, then `All checks passed.`

- [ ] **Step 3: Add the CI workflow**

Create `.github/workflows/ci.yaml`:

```yaml
name: ci

on:
  push:
    branches: [main]
  pull_request:

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: 3.47.5
          channel: stable
          cache: true
      - name: Format, analyze, test
        env:
          FLUTTER: flutter
          DART: dart
        run: tool/check.sh
```

The repository has no remote yet (Phase 6 creates it), so CI first runs after the first push. `subosito/flutter-action@v2` input names (`flutter-version`, `channel`, `cache`) are assumed from its README; verify there if the job fails to set up.

- [ ] **Step 4: Commit**

```bash
git add \
  tool/check.sh \
  .github/workflows/ci.yaml
git commit -m "ci: add tool/check.sh and GitHub Actions workflow" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014gxDHNxF3eTEzoig5VhMXn"
```

---
