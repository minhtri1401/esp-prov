# esp_prov

Provision Espressif devices from Flutter and Dart using Espressif's Unified
Provisioning protocol (protocomm) over Bluetooth LE. Security 0, 1 and 2 are
implemented in pure Dart, with Wi-Fi and Thread flows and custom endpoints.
Works with ESP-IDF 5.1 through 6.x firmware (`wifi_provisioning` and
`network_provisioning`).

| Package | What it is |
|---|---|
| [`esp_prov`](packages/esp_prov) | Flutter entry point: scan, connect, provision. Start here. |
| [`esp_prov_core`](packages/esp_prov_core) | Pure-Dart protocol stack (no Flutter). Bring your own transport. |
| [`esp_prov_ble_universal`](packages/esp_prov_ble_universal) | BLE transport on `universal_ble` (Android, iOS, macOS, Windows, Linux, web). |

## Development

The toolchain is pinned with [FVM](https://fvm.app) to Flutter 3.47.5
(Dart 3.13). FVM 3 reads `.fvmrc`; FVM 2.x needs the local link once:

```bash
fvm use 3.47.5 --force   # FVM 2.x; with FVM 3 run `fvm install` instead
fvm dart --version       # Dart SDK version: 3.13.x
tool/check.sh            # pub get, format check, analyze, tests for every package
```

Regenerating code and fixtures:

```bash
fvm dart pub global activate protoc_plugin 25.1.0
tool/gen_proto.sh      # protoc -> packages/esp_prov_core/lib/src/proto

uv venv .venv && uv pip install --python .venv/bin/python -r tool/requirements.txt
.venv/bin/python tool/gen_fixtures.py   # Espressif esp_prov -> test fixtures
```

Hardware verification against an ESP32-S3 is described in
[docs/hardware-verification.md](docs/hardware-verification.md).
