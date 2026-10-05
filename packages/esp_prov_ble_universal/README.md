# esp_prov_ble_universal

Bluetooth LE transport for
[`esp_prov_core`](https://pub.dev/packages/esp_prov_core), built on
[`universal_ble`](https://pub.dev/packages/universal_ble).

- `UniversalBleScanner`: scans by advertised name prefix
  (case-insensitive), one result per device, primary service UUID from the
  advertisement.
- `UniversalBleTransport`: connects, requests MTU 512 on Android, finds the
  provisioning service, maps endpoint names from the 0x2901 user
  description descriptors (falling back to the ESP-IDF UUID table
  `ff4f`-`ff53`), and runs each request as write-with-response then read.
  Requests are serialised; a dropped link surfaces as `DeviceDisconnected`.

```dart
const scanner = UniversalBleScanner();
final device = await scanner.scan(namePrefix: 'PROV_').first;
final transport = await device.connect();
final session = await EspSession.open(
  transport,
  credentials: const ProvCredentials.none(),
);
```

Most apps should use [`esp_prov`](https://pub.dev/packages/esp_prov)
instead. Permissions and platform setup are described there; this package
does not request runtime permissions.
