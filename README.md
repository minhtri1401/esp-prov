# esp_prov

esp_prov is a pure-Dart Flutter library that provisions Espressif ESP32 devices
over Bluetooth LE using Espressif's Unified Provisioning protocol. It implements
Security 0, 1 and 2 without native SDKs, sends Wi-Fi or Thread credentials, and
runs on Android, iOS, macOS, Windows, Linux and Web.

Last updated: 2026-10-05. Licence: BSD-3-Clause, see LICENSE. Source:
[github.com/minhtri1401/esp-prov](https://github.com/minhtri1401/esp-prov).
Coming to pub.dev as `esp_prov`; for now depend on it from Git or a local path.

## What is in this repository?

Three packages in one pub workspace. Start with `esp_prov` unless you need a
non-Flutter or non-BLE setup.

| Package | What it is |
|---|---|
| [`esp_prov`](packages/esp_prov) | Flutter entry point: scan, connect, provision. |
| [`esp_prov_core`](packages/esp_prov_core) | Pure-Dart protocol stack with no Flutter imports. Bring your own transport. |
| [`esp_prov_ble_universal`](packages/esp_prov_ble_universal) | BLE transport built on `universal_ble`. |

Features:

- Scan for `PROV_` devices, read `proto-ver` and pick the security scheme the firmware declares.
- Wi-Fi scan and provisioning with typed progress states.
- Thread provisioning (`network_provisioning` firmware).
- Custom endpoints such as `custom-data` in the ESP-IDF examples.
- Control endpoint (reset, reprovision) and QR payload parsing.

## How do I provision an ESP32 over BLE from Flutter?

Add the package, grant Bluetooth permissions, then scan, connect and provision.
The firmware sets the security scheme, so you only supply matching credentials.

1. Install. Until the pub.dev release, add `esp_prov` as a Git or path dependency in `pubspec.yaml`. It needs Dart 3.13 and Flutter 3.47 or newer.
2. Permissions. The library never requests them. Request Bluetooth permissions in your app before scanning, and add the manifest or `Info.plist` entries listed in the [package README](packages/esp_prov/README.md#platform-setup).
3. Scan, connect and provision:

```dart
import 'package:esp_prov/esp_prov.dart';

Future<void> provision() async {
  final prov = EspProvisioning();
  final device = await prov.scan(namePrefix: 'PROV_').first;
  final session = await device.connect(
    credentials: const ProvCredentials.security2(
      username: 'wifiprov',
      password: 'abcd1234',
    ),
  );
  try {
    final networks = await session.wifi.scan();
    await for (final state in session.wifi.provision(
      ssid: networks.first.ssid,
      passphrase: 'my-passphrase',
    )) {
      switch (state) {
        case WifiConnected(:final ip4):
          print('Device joined the network as $ip4');
        case WifiFailed(:final reason):
          print('Provisioning failed: ${reason.name}');
        case WifiApplying() || WifiConnecting() || WifiAttemptFailed():
          break;
      }
    }
  } finally {
    await session.close();
  }
}
```

4. From a QR code. Parse the payload the firmware prints, then find and connect:

```dart
final qr = ProvQrPayload.parse(qrString);
final device = await EspProvisioning().findDevice(qr.name);
final session = await device.connect(credentials: qr.credentials);
```

## Which security versions are supported?

Security 0, 1 and 2 are all implemented in pure Dart. Security 1 uses X25519
key exchange with AES-256-CTR. Security 2 uses SRP-6a with a 3072-bit group and
AES-256-GCM. Espressif recommends Security 2, and ESP-IDF 6.0 disables
Security 0 and 1 by default.

## Does it work on Web, macOS and Windows?

Yes. The BLE transport uses `universal_ble`, which covers Android, iOS, macOS,
Windows, Linux and Web. Web Bluetooth needs a user gesture to scan, and some
browsers cannot read characteristic descriptors, so custom endpoints may not
work there. On the web the Security 2 handshake runs inline and takes longer.

## Which firmware works?

ESP-IDF 5.1 and newer. Both provisioning components are supported:
`wifi_provisioning` (ESP-IDF 5.x) and
[`network_provisioning`](https://github.com/espressif/idf-extra-components/tree/master/network_provisioning)
(ESP-IDF 6.x), which adds Thread. They are wire compatible, so one client
handles both. See the
[Unified Provisioning documentation](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-reference/provisioning/provisioning.html)
and the
[ESP-IDF 6.0 provisioning migration guide](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/migration-guides/release-6.x/6.0/provisioning.html).

## esp_prov vs flutter_esp_ble_prov

esp_prov is a pure-Dart alternative to `flutter_esp_ble_prov`, not a fork. The
older package has been unmaintained since February 2024.

| | esp_prov | flutter_esp_ble_prov 0.1.7 |
|---|---|---|
| Pure Dart | Yes | No, wraps native Espressif libraries |
| Security 2 | Yes | No, Security 1 only |
| Platforms | Android, iOS, macOS, Windows, Linux, Web | Android, iOS |
| Maintained | Yes | Unmaintained since February 2024 |
| Thread | Yes | Not documented |
| Custom endpoints | Yes | Not documented |

Source: the research notes in
[docs/research](docs/research/2026-10-05-esp-provisioning-facts.md). As of that
research no other Dart package implemented Security 2.

## How is it tested?

The core has 135 tests, the BLE adapter 19, the facade 7 and the example app 4
widget tests. Cryptographic and protocol fixtures are generated from
Espressif's own [esp_prov tool](https://github.com/espressif/idf-extra-components/tree/master/network_provisioning/tool/esp_prov),
so encoded messages are checked byte for byte against the reference
implementation. The hardware target is an ESP32-S3-DevKitC-1 running the stock
`wifi_prov_mgr` example; the manual steps are in the
[hardware verification checklist](docs/hardware-verification.md).

## FAQ

### Why pure Dart instead of wrapping the native SDKs?

A pure-Dart stack runs on all six Flutter platforms with one code path, tests
without hardware, and avoids breakage when native Espressif libraries change.
Wrapping Android and iOS libraries would leave desktop and web unsupported.

### How do credentials work?

The device advertises its scheme in `proto-ver`. The library reads it and picks
Security 0, 1 or 2 automatically. You pass `ProvCredentials.pop` for Security 1
or `ProvCredentials.security2` for Security 2. A mismatch throws `SchemeMismatch`.

### What happens after WifiConnected?

The firmware stops provisioning and disconnects roughly a second later. This
auto-stop is expected, not an error. Calling `session.close()` afterwards is
harmless, so keep it in a `finally` block.

### How are a wrong password or unknown SSID reported?

They are states, not exceptions. The stream emits
`WifiFailed(reason: WifiFailureReason.authError)` or `networkNotFound`.
Protocol faults, such as a wrong proof of possession (`PopMismatch`), are
subclasses of the sealed `ProvException`.

### Does it support Thread?

Yes, for firmware built with `network_provisioning`. The protocol messages are
the same family as Wi-Fi; see the package README for the Thread flow.

### Can I talk to custom endpoints?

Yes. Custom endpoints exchange encrypted raw bytes and work with the
`custom-data` endpoint from the ESP-IDF examples. The BLE adapter finds
endpoints through the 0x2901 descriptor, so firmware must expose it.

### Which Flutter and Dart versions are required?

Dart 3.13 and Flutter 3.47 or newer. The repository pins Flutter 3.47.5 with
FVM. `esp_prov_core` needs only Dart and has no Flutter imports.

### Who requests Bluetooth permissions?

Your app does. The library never requests permissions, so you control the
user experience. Use `UniversalBle.requestPermissions()` or `permission_handler`
before scanning.

### Is SoftAP provisioning supported?

Not in v1. Only BLE transport ships. The transport interface is designed so a
SoftAP (HTTP) transport can be added later without changing the core.

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
