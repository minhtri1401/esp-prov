# esp_prov

Provision ESP32 devices over Bluetooth LE with Espressif's Unified
Provisioning protocol. Security 0, 1 and 2 (SRP-6a + AES-GCM) are implemented
in pure Dart; no native Espressif SDK is involved.

- Scans for `PROV_` devices, connects, reads `proto-ver` and picks the
  security scheme the firmware declares.
- Wi-Fi scan and provisioning with typed progress states.
- Thread provisioning (`network_provisioning` firmware).
- Custom endpoints (`custom-data` in the ESP-IDF examples).
- Parses the provisioning QR payload printed by the firmware.

## Usage

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

From a QR code string:

```dart
final qr = ProvQrPayload.parse(qrString);
final device = await EspProvisioning().findDevice(qr.name);
final session = await device.connect(credentials: qr.credentials);
```

The firmware chooses the security scheme (advertised through `proto-ver`);
the app only supplies the matching credentials. After `WifiConnected` the
device stops provisioning and disconnects on its own, so a following
`session.close()` is harmless.

This package is an independent, pure-Dart alternative to the unmaintained
`flutter_esp_ble_prov` (not a fork).

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

This package does not request runtime permissions. Request them before
scanning (for example with `UniversalBle.requestPermissions()` or
`permission_handler`).

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

## Security 2 performance

The SRP-6a handshake does 3072-bit modular exponentiation. On native
platforms it runs on a background isolate; on the web it runs inline and
takes noticeably longer.
