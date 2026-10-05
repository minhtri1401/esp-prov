# esp_prov Library Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `esp_prov_core` (pure-Dart Espressif Unified Provisioning with Security 0/1/2, Wi-Fi, Thread, control and custom endpoints), `esp_prov_ble_universal` (BLE transport on universal_ble) and `esp_prov` (Flutter facade plus example app), verified byte for byte against Espressif's esp_prov and on an ESP32-S3.

**Architecture:** A pub workspace of three packages with dependencies pointing down only: `esp_prov` -> `esp_prov_ble_universal` -> `esp_prov_core`. The core holds the whole protocol: generated protobuf, crypto (`AesCtrStream`, `AesGcmCounter`, `Srp6aClient`), the sealed `SecurityScheme`, `EspSession` and the flows. It talks to devices only through the `ProvTransport`/`ProvScanner` interfaces. The BLE adapter implements those on universal_ble. The facade wires them together for apps.

**Tech Stack:** Dart 3.13 / Flutter 3.47.5 via FVM, pub workspaces, protobuf 6.1 + protoc_plugin 25.1.0 + protoc 36.2, cryptography_plus 3.0.0 (X25519, AES-CTR, AES-GCM), crypto 3.0.7 (SHA-256/512), universal_ble 2.3.0 (^2.2.0), very_good_analysis 11.0.0, package:test / flutter_test, Python 3.13 + uv + Espressif esp_prov for fixtures, pana 0.23 for scoring.

**Spec:** `docs/superpowers/specs/2026-10-05-esp-prov-library-design.md`. Facts: `docs/research/2026-10-05-esp-provisioning-facts.md`.

## Global Constraints

- SDK: `environment: sdk: ^3.13.0` in every pubspec; Flutter packages also `flutter: ">=3.47.0"`. Toolchain pinned to Flutter 3.47.5 (Dart 3.13.4) with FVM: `.fvmrc` is committed; the Mac runs FVM 2.4.1, so `fvm use 3.47.5 --force` once per clone (creates the gitignored `.fvm/`).
- Every command in this plan is written `fvm dart ...` / `fvm flutter ...` and runs from the repository root unless it starts with `(cd <dir> && ...)`. The global `flutter` (3.41.8) and Homebrew `dart` (3.6.0) are too old; never use them.
- Pub workspace: the root `pubspec.yaml` lists members explicitly under `workspace:`; each member has `resolution: workspace`. One `pubspec.lock` at the root, committed.
- Packages and names: `packages/esp_prov_core` (pure Dart, must never import `package:flutter` or `package:universal_ble`), `packages/esp_prov_ble_universal` (universal_ble ^2.2.0 is the only BLE backend), `packages/esp_prov` (+ `packages/esp_prov/example`).
- Core dependencies exactly: `crypto: ^3.0.7`, `cryptography_plus: ^3.0.0`, `meta: ^1.16.0`, `protobuf: ^6.1.0`; dev: `test: ^1.25.0` (Flutter 3.47 pins `test_api`, so `^1.32` would not resolve), `very_good_analysis: ^11.0.0`.
- Protobuf: vendored, unmodified `.proto` files in `third_party/espressif/proto` from esp-idf `4d59230ddff16327812782151ef0afef202dc6d7` (protocomm) and idf-extra-components `69e8b21e1a20c8c1c48f5d5cffceeb0bc262eed0` (network_provisioning); `tool/gen_proto.sh` with `-I third_party/espressif/proto`; generated Dart committed in `packages/esp_prov_core/lib/src/proto`, excluded from analysis, imported with prefix `pb`.
- Proto names verbatim: e.g. `WifiConnectFailedReason.WifiNetworkNotFound` (not `NetworkNotFound`), `ThreadNetworkState.Dettached`, `Status.InvalidSession`, `S2Session_Command1`.
- Lints: `very_good_analysis` 11; `dart analyze --fatal-infos` / `flutter analyze --fatal-infos` must print `No issues found!`; `dart format --set-exit-if-changed packages` must report `0 changed`. Package `analysis_options.yaml` files are self-contained (published alone).
- Dart 3.13 constructor syntax is required by the lints: `new(...)`, `const new(...)`, `new named(...)`, `factory parse(...)` inside the class body (call sites unchanged).
- Public API names (spec 3.1-3.7), used identically in every phase: `ProvTransport`, `ProvScanner`, `DiscoveredDevice`, `ProvEndpoints`, `SerialQueue`, `SecurityScheme`/`Security0`/`Security1`/`Security2`, `EspSession.open`, `DeviceInfo`, `ProvCredentials.none/pop/security2`, `WifiProvisioner.scan/provision`, `WifiProvisionState` (`WifiApplying`, `WifiConnecting`, `WifiAttemptFailed`, `WifiConnected`, `WifiFailed`), `WifiFailureReason`, `WifiNetwork`, `WifiAuthMode`, `ThreadProvisioner`, `ThreadProvisionState`, `ProvCtrl`, `CustomEndpoint`, `ProvQrPayload.parse`, `ProvException` hierarchy (`TransportException`, `DeviceDisconnected`, `UnknownEndpoint`, `UnsupportedCapability`, `SchemeMismatch`, `MissingCredentials`, `HandshakeFailed`, `PopMismatch`, `CryptoException`, `ProvStatusException`), `ProvStatus`, `UniversalBleScanner`, `UniversalBleTransport`, `EspProvisioning`, `EspDevice`.
- No nullable booleans in the public API (success criterion 4). Packages never request runtime permissions (spec 3.2).
- Security 2 SRP-6a: RFC 5054 3072-bit N, g = 5, SHA-512, A exactly 384 bytes, padding exactly as tabled in Task 2.6. AES-GCM key `K[0:32]`, 12-byte nonce from `device_nonce`, counter++ after every encrypt and decrypt when `sec_patch_ver >= 1`, fixed when 0, 16-byte tag appended, no AAD.
- Security 1: one continuous AES-256-CTR keystream (IV = `device_random`, full 128-bit big-endian counter) shared by encrypt and decrypt for the whole session.
- Heavy SRP math runs in `offload` (Isolate.run on native, inline on web via a `dart.library.io` conditional export); `esp_prov_core` must keep 6/6 platforms and 160/160 pana points.
- Every commit message ends with the two trailer lines
  `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` and
  `Claude-Session: https://claude.ai/code/session_014gxDHNxF3eTEzoig5VhMXn`
  (each task's commit step passes them as a second `-m`).
- The `rtk` CLI proxy rewrites some commands transparently; write commands plainly. If a command's output looks filtered, rerun it as `rtk proxy <command>`.

## Review Focus

These are the conditions the spec implies but does not spell out, most likely to bite a user first. Each one is pinned by a test in the task that owns the code.

1. **The device drops the BLE link right after receiving a wrong PoP/password** (protocomm_ble kills the connection instead of answering). Expected: `PopMismatch`, never `DeviceDisconnected` or a generic `TransportException`. Pinned in Task 2.8 (`device dropping the link after Cmd1 is a PopMismatch`), Task 2.9 (`device closing the link after the client proof is PopMismatch`), Task 3.3 (FakeDevice end to end, wrong PoP and wrong password), and Task 4.2 (a GATT error that arrives before the disconnect event is still `DeviceDisconnected`).
2. **A transaction fails mid-session** (BLE timeout, GATT 133) after the Security 1/2 cipher state has advanced. Expected: that call throws, and every later request throws `TransportException` telling the caller to reconnect, never mis-decrypted garbage. Pinned in Task 3.3 (`after a failed request the session refuses further requests`).
3. **The stock firmware's QR payload** has no `security` key, and in Security 2 builds carries the password in `pop`. Expected: `ProvQrPayload.credentials` yields `security2(username, password: pop)` or `pop(pop)` accordingly. Pinned in Task 3.6.
4. **SRP values with a leading zero byte** (each about 1 in 256 sessions): A (must re-roll), B as sent by the device (hashed as received in M1), S (K = H(S) unpadded). Expected: the handshake succeeds. Pinned in Task 2.6 and Task 2.9 with the `sec2_short_b`/`sec2_short_s` fixtures and the re-roll test.
5. **Link drops around the end of Wi-Fi provisioning**: after `Connected` (firmware auto-stop about 1 s later) and before it (device power loss). Expected: exactly one terminal state and no stream error; `WifiConnected` in the first case, `WifiFailed(deviceDisconnected)` in the second. Pinned in Task 3.4.

Also pinned, ranked lower: AES-CTR counter carry across the low 64 bits (Task 2.4 fixture `sec1_no_pop_carry`), unknown Wi-Fi auth enum values (3.4), 32-byte multi-byte UTF-8 SSIDs (3.4), Android legacy advertising scan flag for ESP32 (4.3), `findDevice` stopping the BLE scan on timeout (5.1).

## Phases

| # | Phase | File | Tasks | Depends on |
|---|---|---|---|---|
| 1 | Workspace scaffold, vendored protos, codegen, CI | [phase-01-workspace-codegen-ci.md](phase-01-workspace-codegen-ci.md) | 1.1-1.2 | - |
| 2 | Core: transport interfaces, crypto primitives, Security 0/1/2 | [phase-02-core-crypto-security.md](phase-02-core-crypto-security.md) | 2.1-2.9 | 1 |
| 3 | Core: session, flows, QR parser | [phase-03-core-session-flows.md](phase-03-core-session-flows.md) | 3.1-3.6 | 2 |
| 4 | BLE adapter on universal_ble with contract tests | [phase-04-ble-adapter.md](phase-04-ble-adapter.md) | 4.1-4.3 | 1, Task 2.1 |
| 5 | esp_prov facade, example app, docs, hardware verification | [phase-05-facade-example-docs.md](phase-05-facade-example-docs.md) | 5.1-5.4 | 3, 4 |
| 6 | Publish dry-run, verified publisher, CHANGELOGs | [phase-06-publish.md](phase-06-publish.md) | 6.1-6.3 | 5 |

### Dependencies and parallelism

- Phase 1 first, alone.
- The spec says Phases 2 and 4 are independent. Precisely: Phase 4 needs only **Task 2.1** (transport interfaces, error model, `SerialQueue`). After 2.1 is merged, Phase 4 can run in parallel with Tasks 2.2-2.9 and all of Phase 3, e.g. in a separate worktree (`superpowers:using-git-worktrees`). The only shared file is the root `pubspec.yaml` `workspace:` list (Task 4.1 adds one line), which merges trivially.
- Inside Phase 2: 2.2 -> 2.3 -> (2.4, 2.5, 2.6 are independent of each other) -> 2.7 -> 2.8 -> 2.9.
- Inside Phase 3: strictly sequential (each task replaces the core barrel `lib/esp_prov_core.dart`).
- Phase 5 needs Phases 3 and 4. Task 5.3's hardware matrix is a manual gate before Phase 6.
- Manual steps for a person: Task 5.3 Steps 3-4 (ESP-IDF install, flashing, phones) and Task 6.3 Steps 2-5 (GitHub and pub.dev accounts). Task 6.1 asks the user to confirm the license first.

## File structure

```
flutter_esp_ble_prov/
  .fvmrc                                   FVM 3 pin: {"flutter": "3.47.5"}
  .gitignore                               .dart_tool, build, .fvm, .venv, .cache, ...
  pubspec.yaml                             workspace root (explicit member list)
  pubspec.lock                             single workspace lockfile (committed)
  analysis_options.yaml                    very_good_analysis for root-level Dart
  README.md                                overview, dev workflow
  LICENSE                                  Apache-2.0 (Task 6.1, confirm with user)
  .github/workflows/ci.yaml                runs tool/check.sh on Flutter 3.47.5
  .github/workflows/publish.yaml           tag <package>-v<version> -> pub.dev (OIDC)
  docs/hardware-verification.md            ESP-IDF install, 3 firmware builds, device matrix
  docs/releasing.md                        release procedure and one-time account setup
  tool/
    check.sh                               pub get, format, analyze --fatal-infos, tests (all packages)
    gen_proto.sh                           protoc -> packages/esp_prov_core/lib/src/proto
    protoc-gen-dart                        plugin shim: pinned SDK runs protoc_plugin 25.1.0
    gen_fixtures.py                        drives Espressif esp_prov -> test fixtures JSON
    requirements.txt                       cryptography, protobuf<6 for gen_fixtures.py
    pana.sh                                scores one package standalone like pub.dev
  third_party/espressif/proto/
    constants|session|sec0|sec1|sec2.proto            esp-idf components/protocomm/proto
    network_constants|config|scan|ctrl.proto          idf-extra-components network_provisioning/proto
    LICENSE.esp-idf, LICENSE.network_provisioning     Apache-2.0 texts
    README.md                                         source commits, update procedure
  packages/esp_prov_core/                  pure Dart, no Flutter
    lib/esp_prov_core.dart                 barrel (public API only; proto and crypto stay private)
    lib/src/proto/*.pb.dart, *.pbenum.dart generated protobuf (committed)
    lib/src/errors/prov_status.dart        ProvStatus enum (constants.proto Status)
    lib/src/errors/prov_exception.dart     sealed ProvException hierarchy
    lib/src/transport/prov_transport.dart  ProvTransport, ProvScanner, DiscoveredDevice, ProvEndpoints
    lib/src/transport/serial_queue.dart    SerialQueue (one transaction at a time)
    lib/src/crypto/bytes.dart              BigInt <-> bytes, PAD, xor, constant-time compare, hex
    lib/src/crypto/offload.dart            conditional export: Isolate.run vs inline
    lib/src/crypto/offload_isolate.dart    native implementation
    lib/src/crypto/offload_inline.dart     web implementation
    lib/src/crypto/aes_ctr_stream.dart     AesCtrStream: continuous CTR keystream (Security 1)
    lib/src/crypto/aes_gcm_counter.dart    AesGcmCounter: GCM + nonce counter (Security 2)
    lib/src/crypto/srp6a.dart              Srp6aClient, Srp6aProof (esp_srp.c-compatible)
    lib/src/security/security_scheme.dart  sealed SecurityScheme + shared handshake helpers
    lib/src/security/security0|1|2.dart    part files: Security0, Security1, Security2
    lib/src/session/prov_credentials.dart  sealed ProvCredentials
    lib/src/session/device_info.dart       DeviceInfo.parse (proto-ver)
    lib/src/session/scheme_selector.dart   selectScheme(DeviceInfo, ProvCredentials?)
    lib/src/session/esp_session.dart       EspSession
    lib/src/flows/flow_support.dart        scan/config/ctrl request helpers, paged scan runner
    lib/src/flows/wifi_models.dart         WifiAuthMode, WifiNetwork, WifiProvisionState, WifiFailureReason
    lib/src/flows/wifi_provisioner.dart    WifiProvisioner
    lib/src/flows/thread_models.dart       ThreadNetwork, ThreadProvisionState, ThreadFailureReason
    lib/src/flows/thread_provisioner.dart  ThreadProvisioner
    lib/src/flows/prov_ctrl.dart           ProvCtrl
    lib/src/flows/custom_endpoint.dart     CustomEndpoint
    lib/src/qr/prov_qr_payload.dart        ProvQrPayload
    example/esp_prov_core_example.dart     pana example
    test/fixtures/*.json                   generated by tool/gen_fixtures.py (committed)
    test/support/fixtures.dart             fixture loader
    test/support/replay_transport.dart     replays recorded prov-session exchanges
    test/support/fake_device.dart          firmware simulator (Security 0/1/2 device side)
    test/support/network_handlers.dart     scripted prov-scan / prov-config handlers
    test/{proto,errors,transport,crypto,security,session,flows,qr}/*_test.dart
  packages/esp_prov_ble_universal/
    lib/esp_prov_ble_universal.dart        barrel
    lib/src/endpoint_discovery.dart        0x2901 names, UUID-table fallback, UUID derivation
    lib/src/transport.dart                 UniversalBleTransport, pickProvisioningService
    lib/src/scanner.dart                   UniversalBleScanner, UniversalBleDevice
    test/support/fake_ble_platform.dart    FakeBlePlatform for UniversalBle.setInstance
    test/{endpoint_discovery,transport,scanner}_test.dart
  packages/esp_prov/
    lib/esp_prov.dart                      re-exports core + BLE types
    lib/src/esp_provisioning.dart          EspProvisioning, EspDevice
    test/esp_provisioning_test.dart
    example/                               Flutter app (all 6 platforms)
      lib/main.dart                        EspProvExampleApp, describeError
      lib/home_page.dart                   QR paste, credentials, scan list
      lib/session_page.dart                device info, Wi-Fi scan/provision, custom-data
      test/widget_test.dart
      integration_test/provisioning_test.dart   hardware test (--dart-define parameters)
```

## Decisions and deviations from the spec

- `SecurityScheme.encrypt/decrypt` return `Future<Uint8List>` (spec 3.3 shows synchronous): cryptography_plus is async-only.
- The error model is built in Task 2.1 (spec 8 puts it in phase 3) because the security layer throws it.
- `DeviceInfo.version` (spec comment says `ver`) and `ProvQrPayload.version` (JSON key `ver`).
- Missing `sec_ver` means 0 when `cap` has `no_sec`, else 1 (esp_prov's rule, a superset of spec 3.4).
- `ThreadProvisionState` adds `ThreadApplying`/`ThreadAttaching` and reasons `timeout`/`deviceDisconnected` to mirror Wi-Fi.
- Wi-Fi provisioning validates SSID 1..32 bytes, passphrase <= 64 bytes, BSSID 6 bytes (spec section 7 risk table).
- `Srp6aClient` is a static, pure API plus `Srp6aProof`, so it can run inside `Isolate.run`.
- Tests use hand-written fakes (`FakeDevice`, `ReplayTransport`, `FakeBlePlatform`); `mocktail` (spec 5) is not added because nothing needs it.
- The hardware integration test lives in `packages/esp_prov/example/integration_test/` (spec 4 shows `packages/esp_prov/integration_test/`): integration tests need an app.
- `esp_prov` moved out of ESP-IDF; fixtures use idf-extra-components `network_provisioning/tool/esp_prov` (the brief's `tools/esp_prov` path no longer exists on master).
- The firmware example used for hardware is `examples/provisioning/wifi_prov_mgr` in ESP-IDF v5.4.2 (and v6.0 optionally). On ESP-IDF master it moved to idf-extra-components `network_provisioning/examples/wifi_prov`.

## Assumptions to confirm or verify

- License Apache-2.0 for all packages (Task 6.1 asks the user).
- GitHub repository `https://github.com/MinhTri1401/esp_prov` in all pubspecs (Task 6.3 asks the user; no remote exists yet).
- `subosito/flutter-action@v2` inputs and the publish workflow's OIDC token pickup by `flutter pub publish` (Tasks 1.2, 6.2: verify against their docs on first run).
- Hardware behaviour not reproducible on this Mac (Task 5.3): iOS long writes without MTU negotiation, Security 2 timing under 1 s, firmware log strings.
