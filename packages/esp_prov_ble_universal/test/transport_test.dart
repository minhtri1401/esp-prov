import 'dart:convert';

import 'package:esp_prov_ble_universal/esp_prov_ble_universal.dart';
import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

import 'support/fake_ble_platform.dart';

const _service = '021a9004-0382-4aea-bff4-6b3f1c5adfb4';
const _device = 'AA:BB:CC:DD:EE:FF';

String _uuid(int id) => characteristicUuidFor(_service, id);

const _names = {
  0xff4f: 'prov-ctrl',
  0xff50: 'prov-scan',
  0xff51: 'prov-session',
  0xff52: 'prov-config',
  0xff53: 'proto-ver',
  0xff54: 'custom-data',
};

FakeBlePlatform _platform({
  String serviceUuid = _service,
  List<BleService>? extraServices,
  Map<String, Responder> responders = const {},
  Duration transactionDelay = Duration.zero,
}) => FakeBlePlatform(
  services: [
    BleService('1800', const []),
    BleService(serviceUuid, [
      for (final id in _names.keys)
        BleCharacteristic(characteristicUuidFor(serviceUuid, id), const [], [
          BleDescriptor('2901'),
        ]),
    ]),
    ...?extraServices,
  ],
  userDescriptions: {
    for (final e in _names.entries)
      characteristicUuidFor(serviceUuid, e.key): e.value,
  },
  responders: responders,
  transactionDelay: transactionDelay,
);

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('discovers endpoints from 0x2901 descriptors', () async {
    final platform = _platform();
    UniversalBle.setInstance(platform);
    final transport = await UniversalBleTransport.connect(
      _device,
      advertisedServiceUuid: _service,
    );
    expect(transport.endpoints, _names.values.toSet());
    expect(transport.characteristicFor('custom-data'), _uuid(0xff54));
    expect(transport.warnings, isEmpty);
  });

  test('requests MTU 512 on Android only', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final android = _platform();
    UniversalBle.setInstance(android);
    await UniversalBleTransport.connect(
      _device,
      advertisedServiceUuid: _service,
    );
    expect(android.log, contains('mtu 512'));

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final ios = _platform();
    UniversalBle.setInstance(ios);
    await UniversalBleTransport.connect(
      _device,
      advertisedServiceUuid: _service,
    );
    expect(ios.log.where((l) => l.startsWith('mtu')), isEmpty);
  });

  test('falls back to the firmware default service UUID', () async {
    UniversalBle.setInstance(_platform(serviceUuid: defaultServiceUuid));
    final transport = await UniversalBleTransport.connect(_device);
    expect(transport.serviceUuid, defaultServiceUuid);
  });

  test('without any provisioning service it disconnects and throws', () async {
    final platform = FakeBlePlatform(
      services: [BleService('1800', const []), BleService('180a', const [])],
    );
    UniversalBle.setInstance(platform);
    await expectLater(
      UniversalBleTransport.connect(_device),
      throwsA(isA<TransportException>()),
    );
    expect(platform.log.last, 'disconnect');
  });

  test(
    'send writes with response, then reads the same characteristic',
    () async {
      final platform = _platform(
        responders: {_uuid(0xff54): (w) => utf8.encode('re:${utf8.decode(w)}')},
      );
      UniversalBle.setInstance(platform);
      final transport = await UniversalBleTransport.connect(
        _device,
        advertisedServiceUuid: _service,
      );
      final response = await transport.send('custom-data', _bytes('hi'));
      expect(utf8.decode(response), 're:hi');
      expect(platform.log.skipWhile((l) => !l.startsWith('write')), [
        'write ${_uuid(0xff54)} hi',
        'read ${_uuid(0xff54)}',
      ]);
    },
  );

  test('concurrent sends never interleave', () async {
    final platform = _platform(
      transactionDelay: const Duration(milliseconds: 5),
    );
    UniversalBle.setInstance(platform);
    final transport = await UniversalBleTransport.connect(
      _device,
      advertisedServiceUuid: _service,
    );
    await Future.wait([
      transport.send('prov-scan', _bytes('a')),
      transport.send('prov-config', _bytes('b')),
    ]);
    expect(platform.log.skipWhile((l) => !l.startsWith('write')), [
      'write ${_uuid(0xff50)} a',
      'read ${_uuid(0xff50)}',
      'write ${_uuid(0xff52)} b',
      'read ${_uuid(0xff52)}',
    ]);
  });

  test('unknown endpoint throws UnknownEndpoint', () async {
    UniversalBle.setInstance(_platform());
    final transport = await UniversalBleTransport.connect(
      _device,
      advertisedServiceUuid: _service,
    );
    await expectLater(
      transport.send('nope', _bytes('x')),
      throwsA(isA<UnknownEndpoint>()),
    );
  });

  test('a link drop emits onDisconnected and fails later sends', () async {
    final platform = _platform();
    UniversalBle.setInstance(platform);
    final transport = await UniversalBleTransport.connect(
      _device,
      advertisedServiceUuid: _service,
    );
    final dropped = transport.onDisconnected.first;
    platform.dropLink(_device);
    await dropped;
    await expectLater(
      transport.send('custom-data', _bytes('x')),
      throwsA(isA<DeviceDisconnected>()),
    );
    await transport.disconnect();
    await transport.disconnect();
  });

  test('a drop during a transaction surfaces as DeviceDisconnected', () async {
    late FakeBlePlatform platform;
    platform = _platform(
      responders: {
        // The error arrives before the connection event is delivered.
        _uuid(0xff52): (w) {
          platform.dropLink(_device);
          throw Exception('GATT 133');
        },
      },
    );
    UniversalBle.setInstance(platform);
    final transport = await UniversalBleTransport.connect(
      _device,
      advertisedServiceUuid: _service,
    );
    await expectLater(
      transport.send('prov-config', _bytes('x')),
      throwsA(isA<DeviceDisconnected>()),
    );
  });

  test('other BLE errors become TransportException', () async {
    UniversalBle.setInstance(
      _platform(responders: {_uuid(0xff52): (w) => throw Exception('133')}),
    );
    final transport = await UniversalBleTransport.connect(
      _device,
      advertisedServiceUuid: _service,
    );
    await expectLater(
      transport.send('prov-config', _bytes('x')),
      throwsA(isA<TransportException>()),
    );
  });
}
