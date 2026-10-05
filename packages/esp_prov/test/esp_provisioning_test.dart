import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:esp_prov/esp_prov.dart';
import 'package:flutter_test/flutter_test.dart';

/// SessionData{sec0: Sec0Payload{msg: S0_Session_Response, sr: {}}}.
const _sec0SessionResponse = [0x52, 0x05, 0x08, 0x01, 0xaa, 0x01, 0x00];

final class _FakeTransport implements ProvTransport {
  new(this.protoVer);

  final String protoVer;
  int disconnects = 0;

  @override
  Set<String> get endpoints => {'proto-ver', 'prov-session'};

  @override
  Stream<void> get onDisconnected => const Stream.empty();

  @override
  Future<void> disconnect() async => disconnects++;

  @override
  Future<Uint8List> send(String endpoint, Uint8List request) async =>
      Uint8List.fromList(
        endpoint == 'proto-ver' ? utf8.encode(protoVer) : _sec0SessionResponse,
      );
}

final class _FakeDevice implements DiscoveredDevice {
  new(this.name, this.transport);

  @override
  final String name;

  final _FakeTransport transport;

  @override
  String get id => name;

  @override
  int? get rssi => -50;

  @override
  String get serviceUuid => '';

  @override
  Future<ProvTransport> connect() async => transport;
}

final class _FakeScanner implements ProvScanner {
  new(this.devices);

  final List<DiscoveredDevice> devices;
  String? lastPrefix;

  @override
  Stream<DiscoveredDevice> scan({String namePrefix = 'PROV_'}) {
    lastPrefix = namePrefix;
    return Stream.fromIterable(devices);
  }
}

final class _StreamScanner implements ProvScanner {
  new(this.stream);

  final Stream<DiscoveredDevice> stream;

  @override
  Stream<DiscoveredDevice> scan({String namePrefix = 'PROV_'}) => stream;
}

void main() {
  const sec0 = '{"prov":{"ver":"v1.1","sec_ver":0,"cap":["no_sec"]}}';
  const sec2 = '{"prov":{"ver":"v1.1","sec_ver":2,"sec_patch_ver":1}}';

  test('scan wraps discovered devices', () async {
    final scanner = _FakeScanner([_FakeDevice('PROV_1', _FakeTransport(sec0))]);
    final devices = await EspProvisioning(scanner: scanner).scan().toList();
    expect(devices.single.name, 'PROV_1');
    expect(scanner.lastPrefix, 'PROV_');
  });

  test('connect opens a session', () async {
    final device = EspDevice(_FakeDevice('PROV_1', _FakeTransport(sec0)));
    final session = await device.connect();
    expect(session.securityVersion, 0);
  });

  test('a failed connect closes the link', () async {
    final transport = _FakeTransport(sec2);
    final device = EspDevice(_FakeDevice('PROV_1', transport));
    await expectLater(device.connect(), throwsA(isA<MissingCredentials>()));
    expect(transport.disconnects, 1);
  });

  test('findDevice matches the exact QR name', () async {
    final scanner = _FakeScanner([
      _FakeDevice('PROV_1A', _FakeTransport(sec0)),
      _FakeDevice('prov_1', _FakeTransport(sec0)),
    ]);
    final device = await EspProvisioning(scanner: scanner).findDevice('PROV_1');
    expect(device.name, 'prov_1');
  });

  test('findDevice times out and stops scanning', () async {
    var cancelled = false;
    final controller = StreamController<DiscoveredDevice>(
      onCancel: () => cancelled = true,
    );
    final scanner = _StreamScanner(controller.stream);
    await expectLater(
      EspProvisioning(scanner: scanner)
          .findDevice('PROV_X', timeout: const Duration(milliseconds: 20)),
      throwsA(isA<TransportException>()),
    );
    expect(cancelled, isTrue);
  });

  test('findDevice reports a missing device', () async {
    final scanner = _FakeScanner(const []);
    await expectLater(
      EspProvisioning(scanner: scanner).findDevice('PROV_X'),
      throwsA(isA<TransportException>()),
    );
  });
}
