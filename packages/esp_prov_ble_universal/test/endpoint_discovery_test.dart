import 'dart:typed_data';

import 'package:esp_prov_ble_universal/esp_prov_ble_universal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

const _service = '021a9004-0382-4aea-bff4-6b3f1c5adfb4';

BleCharacteristic _char(int id, {bool described = true}) => BleCharacteristic(
  characteristicUuidFor(_service, id),
  [CharacteristicProperty.read, CharacteristicProperty.write],
  [if (described) BleDescriptor('2901')],
);

void main() {
  test('characteristic UUID replaces bytes 12-13 of the service UUID', () {
    expect(
      characteristicUuidFor(_service, 0xff51),
      '021aff51-0382-4aea-bff4-6b3f1c5adfb4',
    );
    expect(
      characteristicUuidFor('1775244D-6B43-439B-877C-060F2D9BED07', 0xff53),
      '1775ff53-6b43-439b-877c-060f2d9bed07',
    );
  });

  test('endpointIdOf inverts characteristicUuidFor', () {
    expect(
      endpointIdOf(_service, '021AFF50-0382-4AEA-BFF4-6B3F1C5ADFB4'),
      0xff50,
    );
    expect(
      endpointIdOf(_service, '00002a00-0000-1000-8000-00805f9b34fb'),
      isNull,
    );
  });

  test('0x2901 names win; missing ones use the UUID table', () async {
    final service = BleService(_service, [
      _char(0xff51),
      _char(0xff53, described: false),
      _char(0xff54),
      _char(0xff55, described: false),
    ]);
    final names = {
      characteristicUuidFor(_service, 0xff51): 'PROV-SESSION\u0000',
      characteristicUuidFor(_service, 0xff54): 'custom-data',
    };
    final map = await discoverEndpoints(
      service,
      (uuid) async => Uint8List.fromList(names[uuid]!.codeUnits),
    );
    expect(map.characteristics, {
      'prov-session': characteristicUuidFor(_service, 0xff51),
      'custom-data': characteristicUuidFor(_service, 0xff54),
      'proto-ver': characteristicUuidFor(_service, 0xff53),
    });
    expect(map.warnings.single, contains('021aff55'));
  });

  test('a failing descriptor read falls back to the table', () async {
    final service = BleService(_service, [_char(0xff52)]);
    final map = await discoverEndpoints(
      service,
      (uuid) => Future.error(Exception('web: descriptors unsupported')),
    );
    expect(map.characteristics.keys, ['prov-config']);
    expect(map.warnings.single, contains('0x2901'));
  });

  test('a repeated 0x2901 name keeps the first and warns', () async {
    final service = BleService(_service, [_char(0xff51), _char(0xff54)]);
    final map = await discoverEndpoints(
      service,
      (uuid) async => Uint8List.fromList('prov-session'.codeUnits),
    );
    expect(map.characteristics, {
      'prov-session': characteristicUuidFor(_service, 0xff51),
    });
    expect(map.warnings.single, contains('021aff54'));
  });

  test('a fallback id whose name is already taken warns', () async {
    final service = BleService(_service, [
      _char(0xff54),
      _char(0xff51, described: false),
    ]);
    final map = await discoverEndpoints(
      service,
      (uuid) async => Uint8List.fromList('prov-session'.codeUnits),
    );
    expect(map.characteristics, {
      'prov-session': characteristicUuidFor(_service, 0xff54),
    });
    expect(map.warnings.single, contains('already mapped'));
    expect(map.warnings.single, contains('021aff51'));
  });
}
