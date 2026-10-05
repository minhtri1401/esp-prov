import 'package:esp_prov_ble_universal/esp_prov_ble_universal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

import 'support/fake_ble_platform.dart';

void main() {
  test('filters by name prefix case-insensitively and dedupes by id', () async {
    final platform = FakeBlePlatform(
      adverts: [
        BleDevice(
          deviceId: '1',
          name: 'PROV_AAA',
          rssi: -40,
          services: ['021A9004-0382-4AEA-BFF4-6B3F1C5ADFB4'],
        ),
        BleDevice(deviceId: '2', name: 'Headphones', rssi: -30),
        BleDevice(deviceId: '1', name: 'PROV_AAA', rssi: -41),
        BleDevice(deviceId: '3', name: 'prov_bbb', rssi: -70),
        BleDevice(deviceId: '4', name: null, rssi: -70),
      ],
    );
    UniversalBle.setInstance(platform);
    final devices = await const UniversalBleScanner().scan().take(2).toList();
    expect(devices.map((d) => d.id), ['1', '3']);
    expect(devices.first.serviceUuid, '021a9004-0382-4aea-bff4-6b3f1c5adfb4');
    expect(devices.last.serviceUuid, isEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(platform.log, ['startScan', 'stopScan']);
    expect(platform.lastScanConfig!.android!.legacy, isTrue);
  });

  test(
    'passes web services and the legacy flag; cancelling stops the scan',
    () async {
      final platform = FakeBlePlatform(
        adverts: [BleDevice(deviceId: '1', name: 'PROV_A', rssi: -40)],
      );
      UniversalBle.setInstance(platform);
      const scanner = UniversalBleScanner(
        webServiceUuids: ['abcd'],
        androidLegacyScan: false,
      );
      final sub = scanner.scan(namePrefix: 'prov_').listen((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(platform.lastScanConfig!.android!.legacy, isFalse);
      expect(platform.lastScanConfig!.web!.optionalServices, ['abcd']);
      await sub.cancel();
      expect(platform.log, ['startScan', 'stopScan']);
    },
  );

  test(
    'connect() hands the advertised service UUID to the transport',
    () async {
      const other = '11111111-2222-3333-4444-555555555555';
      BleService svc(String uuid) => BleService(uuid, [
        BleCharacteristic(characteristicUuidFor(uuid, 0xff51), const [], [
          BleDescriptor('2901'),
        ]),
      ]);
      final platform = FakeBlePlatform(
        services: [svc(defaultServiceUuid), svc(other)],
        userDescriptions: {
          characteristicUuidFor(defaultServiceUuid, 0xff51): 'prov-session',
          characteristicUuidFor(other, 0xff51): 'prov-session',
        },
      );
      UniversalBle.setInstance(platform);
      const advertised = UniversalBleDevice(
        id: 'AA:BB',
        name: 'PROV_X',
        rssi: null,
        serviceUuid: other,
      );
      final transport = await advertised.connect();
      expect(transport.serviceUuid, other);
      await transport.disconnect();

      const bare = UniversalBleDevice(
        id: 'AA:BB',
        name: 'PROV_X',
        rssi: null,
        serviceUuid: '',
      );
      final fallback = await bare.connect();
      expect(fallback.serviceUuid, defaultServiceUuid);
      await fallback.disconnect();
    },
  );
}
