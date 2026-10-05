# esp_prov_core

Pure-Dart client for Espressif Unified Provisioning (protocomm), with no
Flutter dependency. It runs on all six platforms and in plain Dart programs.

It provides:

- `EspSession`: reads `proto-ver`, chooses Security 0, 1 or 2 from the
  firmware, runs the handshake and encrypts every request.
- Security 1 (X25519, AES-256-CTR, proof of possession) and Security 2
  (SRP-6a 3072-bit SHA-512, AES-256-GCM), verified byte for byte against
  Espressif's `esp_prov` tool.
- `WifiProvisioner`, `ThreadProvisioner`, `ProvCtrl`, `CustomEndpoint`.
- `ProvQrPayload` for the QR JSON printed by the firmware.

You supply a `ProvTransport`. For Bluetooth LE use
[`esp_prov_ble_universal`](https://pub.dev/packages/esp_prov_ble_universal),
or the Flutter package [`esp_prov`](https://pub.dev/packages/esp_prov), which
wires everything together.

```dart
import 'dart:typed_data';

import 'package:esp_prov_core/esp_prov_core.dart';

Future<void> run(ProvTransport transport) async {
  final session = await EspSession.open(
    transport,
    credentials: const ProvCredentials.pop('abcd1234'),
  );
  final reply = await session.custom('custom-data').send(
    Uint8List.fromList('hello'.codeUnits),
  );
  print(String.fromCharCodes(reply));
  await session.close();
}
```

A transport implements four members:

```dart
abstract interface class ProvTransport {
  Set<String> get endpoints;
  Future<Uint8List> send(String endpoint, Uint8List request);
  Stream<void> get onDisconnected;
  Future<void> disconnect();
}
```

`send` is one protocomm transaction (for BLE: write with response, then read
the same characteristic). Implementations must serialise concurrent calls.
