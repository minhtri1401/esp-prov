# esp_prov

esp_prov is a pure-Dart Flutter library that provisions Espressif ESP32
devices over Bluetooth LE using Espressif's Unified Provisioning protocol. It
implements Security 0, 1 and 2 without native SDKs, sends Wi-Fi or Thread
credentials, and runs on Android, iOS, macOS, Windows, Linux and Web.

Licence: BSD-3-Clause, see [LICENSE](https://github.com/minhtri1401/esp-prov/blob/main/LICENSE). Source:
[github.com/minhtri1401/esp-prov](https://github.com/minhtri1401/esp-prov).

Features:

- Scan for `PROV_` devices, read `proto-ver` and pick the security scheme the firmware declares.
- Wi-Fi scan and provisioning with typed progress states.
- Thread provisioning (`network_provisioning` firmware).
- Custom endpoints such as `custom-data` in the ESP-IDF examples.
- Control endpoint (reset, reprovision) and QR payload parsing.

## Install

```bash
flutter pub add esp_prov
```

It needs Dart 3.13 and Flutter 3.47 or newer.

## Usage

Add the package, grant Bluetooth permissions (see [Platform setup](#platform-setup)),
then scan, connect and provision. The firmware sets the security scheme, so you
only supply matching credentials.

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

From a QR code string. Parse the payload the firmware prints, then find
and connect:

```dart
final qr = ProvQrPayload.parse(qrString);
final device = await EspProvisioning().findDevice(qr.name);
final session = await device.connect(credentials: qr.credentials);
```

The firmware chooses the security scheme (advertised through `proto-ver`);
the app only supplies the matching credentials: `ProvCredentials.pop` for
Security 1 or `ProvCredentials.security2` for Security 2. After
`WifiConnected` the firmware stops provisioning and disconnects roughly a
second later. This is expected, not an error. Calling `session.close()`
afterwards is harmless, so keep it in a `finally` block.

The session also exposes `session.thread` (Thread provisioning, for firmware
built with `network_provisioning`), `session.ctrl` (reset and reprovision) and
`session.custom(name)` for custom endpoints. Custom endpoints exchange
encrypted raw bytes and work with the `custom-data` endpoint from the ESP-IDF
examples. The BLE adapter finds endpoints through the 0x2901 descriptor, so the
firmware must expose it.

### Errors

All failures are subclasses of the sealed `ProvException`:
`PopMismatch` (wrong PoP or password), `SchemeMismatch` (credential kind does
not match the firmware), `MissingCredentials`, `DeviceDisconnected`,
`TransportException`, `UnknownEndpoint`, `UnsupportedCapability`,
`HandshakeFailed`, `CryptoException`, `ProvStatusException`. Wrong Wi-Fi
passphrase or unknown SSID are not exceptions: they arrive as
`WifiFailed(reason: WifiFailureReason.authError | networkNotFound)`.
`WifiFailureReason` also has `timeout` and `deviceDisconnected`. Protocol
faults (`ProvException` subclasses) arrive as stream errors on `provision()`,
so callers should handle both states and errors.

## Platform setup

This package does not request runtime permissions. Request them in your app
before scanning, for example with `UniversalBle.requestPermissions()` or
`permission_handler`.

**Android** (`android/app/src/main/AndroidManifest.xml`):

```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" android:maxSdkVersion="28" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />
```

**iOS and macOS** (`Info.plist`): `NSBluetoothAlwaysUsageDescription`.

**macOS** entitlements: `com.apple.security.device.bluetooth`.

**Web**: Web Bluetooth needs a user gesture to scan and only exposes
services listed in `UniversalBleScanner(webServiceUuids: ...)`. Some browsers
cannot read characteristic descriptors; the standard endpoints still work
through the UUID fallback, custom endpoints may not.

The BLE transport uses `universal_ble`, which covers Android, iOS, macOS,
Windows, Linux and Web.

## Security versions

Security 0, 1 and 2 are all implemented in pure Dart. Security 1 uses X25519
key exchange with AES-256-CTR. Security 2 uses SRP-6a with a 3072-bit group and
AES-256-GCM. Espressif recommends Security 2, and ESP-IDF 6.0 disables
Security 0 and 1 by default.

The Security 2 handshake does 3072-bit modular exponentiation. On native
platforms it runs on a background isolate; on the web it runs inline and takes
noticeably longer.

## Firmware requirements

ESP-IDF 5.1 and newer. Both provisioning components are supported:
`wifi_provisioning` (ESP-IDF 5.x) and
[`network_provisioning`](https://github.com/espressif/idf-extra-components/tree/master/network_provisioning)
(ESP-IDF 6.x), which adds Thread. They are wire compatible, so one client
handles both. See the
[Unified Provisioning documentation](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-reference/provisioning/provisioning.html)
and the
[ESP-IDF 6.0 provisioning migration guide](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/migration-guides/release-6.x/6.0/provisioning.html).

SoftAP provisioning is not supported in v1. Only the BLE transport ships. The
transport interface is designed so a SoftAP (HTTP) transport can be added later
without changing the core.

## Packages

`esp_prov` is the Flutter entry point. It is built from two lower-level
packages, which you can use directly when you need a non-Flutter or non-BLE
setup.

| Package | What it is |
|---|---|
| [`esp_prov`](https://pub.dev/packages/esp_prov) | Flutter entry point: scan, connect, provision. |
| [`esp_prov_core`](https://pub.dev/packages/esp_prov_core) | Pure-Dart protocol stack with no Flutter imports. Bring your own transport, for example for a command-line tool, a server or a different BLE stack. |
| [`esp_prov_ble_universal`](https://pub.dev/packages/esp_prov_ble_universal) | BLE transport built on `universal_ble`. Use it with `esp_prov_core` if you want the transport without the facade. |

Start with `esp_prov` unless you have one of those needs.

## esp_prov vs flutter_esp_ble_prov

esp_prov is an independent, pure-Dart alternative to `flutter_esp_ble_prov`,
not a fork. The older package has been unmaintained since February 2024.

| | esp_prov | flutter_esp_ble_prov 0.1.7 |
|---|---|---|
| Pure Dart | Yes | No, wraps native Espressif libraries |
| Security 2 | Yes | No, Security 1 only |
| Platforms | Android, iOS, macOS, Windows, Linux, Web | Android, iOS |
| Maintained | Yes | Unmaintained since February 2024 |
| Thread | Yes | Not documented |
| Custom endpoints | Yes | Not documented |

## Testing

Cryptographic and protocol fixtures are generated from Espressif's own
[esp_prov tool](https://github.com/espressif/idf-extra-components/tree/master/network_provisioning/tool/esp_prov),
so encoded messages are checked byte for byte against the reference
implementation. On hardware, the stock `wifi_prov_mgr` example (ESP-IDF 5.4)
has been provisioned over BLE from Android (Pixel 8), iOS and macOS with
Security 1 and 2, using an ESP32 board.

## FAQ

### Why pure Dart instead of wrapping the native SDKs?

A pure-Dart stack runs on all six Flutter platforms with one code path, tests
without hardware, and avoids breakage when native Espressif libraries change.
Wrapping Android and iOS libraries would leave desktop and web unsupported.

### How do credentials work?

The device advertises its scheme in `proto-ver`. The library reads it and picks
Security 0, 1 or 2 automatically. You pass `ProvCredentials.pop` for Security 1
or `ProvCredentials.security2` for Security 2. A mismatch throws `SchemeMismatch`.

### Who requests Bluetooth permissions?

Your app does. The library never requests permissions, so you control the
user experience.

## Issues

Report bugs and feature requests at
[github.com/minhtri1401/esp-prov/issues](https://github.com/minhtri1401/esp-prov/issues).
