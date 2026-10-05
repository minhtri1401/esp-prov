import 'dart:async';

import 'package:esp_prov_ble_universal/src/transport.dart';
import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:universal_ble/universal_ble.dart';

/// A [ProvScanner] backed by `universal_ble`.
///
/// The adapter does not request runtime permissions; the app must hold
/// Bluetooth scan/connect permissions before calling [scan].
final class UniversalBleScanner implements ProvScanner {
  /// Creates a scanner. [webServiceUuids] are passed as Web Bluetooth
  /// `optionalServices` so the browser lets the page open them.
  /// [androidLegacyScan] makes Android report legacy (BLE 4.x)
  /// advertisements, which is what ESP32 provisioning firmware sends.
  const new({
    this.webServiceUuids = const [defaultServiceUuid, exampleServiceUuid],
    this.androidLegacyScan = true,
  });

  /// Service UUIDs the web build may access.
  final List<String> webServiceUuids;

  /// Passed as `AndroidOptions.legacy`.
  final bool androidLegacyScan;

  @override
  Stream<DiscoveredDevice> scan({String namePrefix = 'PROV_'}) {
    final prefix = namePrefix.toLowerCase();
    final seen = <String>{};
    StreamSubscription<BleDevice>? subscription;
    late final StreamController<DiscoveredDevice> controller;
    controller = StreamController<DiscoveredDevice>(
      onListen: () {
        subscription = UniversalBle.scanStream.listen((device) {
          final name = device.name ?? '';
          if (!name.toLowerCase().startsWith(prefix)) return;
          if (!seen.add(device.deviceId)) return;
          controller.add(
            UniversalBleDevice(
              id: device.deviceId,
              name: name,
              rssi: device.rssi,
              serviceUuid: device.services.isEmpty
                  ? ''
                  : BleUuidParser.stringOrNull(device.services.first) ?? '',
            ),
          );
        }, onError: controller.addError);
        unawaited(
          UniversalBle.startScan(
            platformConfig: PlatformConfig(
              android: AndroidOptions(legacy: androidLegacyScan),
              web: WebOptions(optionalServices: webServiceUuids),
            ),
          ).catchError((Object e) {
            controller.addError(
              TransportException('Could not start the BLE scan.', cause: e),
            );
          }),
        );
      },
      onCancel: () async {
        await subscription?.cancel();
        await UniversalBle.stopScan();
      },
    );
    return controller.stream;
  }
}

/// A provisioning device seen by [UniversalBleScanner].
final class UniversalBleDevice implements DiscoveredDevice {
  /// Creates a device handle.
  const new({
    required this.id,
    required this.name,
    required this.rssi,
    required this.serviceUuid,
  });

  @override
  final String id;

  @override
  final String name;

  @override
  final int? rssi;

  /// Advertised primary service UUID, or empty when the advertisement did
  /// not include one (the transport then falls back, see
  /// `pickProvisioningService`).
  @override
  final String serviceUuid;

  @override
  Future<UniversalBleTransport> connect() => UniversalBleTransport.connect(
    id,
    advertisedServiceUuid: serviceUuid.isEmpty ? null : serviceUuid,
  );
}
