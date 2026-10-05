/// Provision Espressif devices over Bluetooth LE.
///
/// ```dart
/// final prov = EspProvisioning();
/// await for (final device in prov.scan()) {
///   final session = await device.connect(
///     credentials: const ProvCredentials.security2(
///       username: 'wifiprov',
///       password: 'abcd1234',
///     ),
///   );
///   // session.wifi.scan(), session.wifi.provision(...)
/// }
/// ```
library;

export 'package:esp_prov_ble_universal/esp_prov_ble_universal.dart'
    show
        UniversalBleDevice,
        UniversalBleScanner,
        UniversalBleTransport,
        defaultServiceUuid,
        exampleServiceUuid;
export 'package:esp_prov_core/esp_prov_core.dart';

export 'src/esp_provisioning.dart';
