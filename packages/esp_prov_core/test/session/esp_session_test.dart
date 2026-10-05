import 'dart:convert';
import 'dart:typed_data';

import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:test/test.dart';

import '../support/fake_device.dart';

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

FakeDevice _echoDevice(String protoVer, {String pop = ''}) => FakeDevice(
  protoVer: protoVer,
  pop: pop,
  extraEndpoints: {'custom-data'},
  handlers: {
    'custom-data': (request) => [...request.reversed],
  },
);

void main() {
  test('Security 0 session round-trips a custom endpoint', () async {
    final device = _echoDevice(protoVerJson(secVer: 0, caps: ['no_sec']));
    final session = await EspSession.open(device);
    expect(session.securityVersion, 0);
    expect(await session.custom('custom-data').send(_bytes('abc')), [
      ...utf8.encode('cba'),
    ]);
  });

  test('Security 1 session keeps one keystream across messages', () async {
    final device = _echoDevice(protoVerJson(secVer: 1), pop: 'abcd1234');
    final session = await EspSession.open(
      device,
      credentials: const ProvCredentials.pop('abcd1234'),
    );
    final endpoint = session.custom('custom-data');
    for (final text in ['a', 'hello world 1234', 'x' * 40]) {
      expect(
        utf8.decode(await endpoint.send(_bytes(text))),
        [...text.split('').reversed].join(),
      );
    }
  });

  test('Security 1 with a wrong PoP throws PopMismatch', () async {
    final device = _echoDevice(protoVerJson(secVer: 1), pop: 'abcd1234');
    await expectLater(
      EspSession.open(device, credentials: const ProvCredentials.pop('nope')),
      throwsA(isA<PopMismatch>()),
    );
    expect(device.isConnected, isFalse);
  });

  for (final patch in [0, 1]) {
    test('Security 2 session (sec_patch_ver $patch)', () async {
      final device = _echoDevice(protoVerJson(secVer: 2, secPatchVer: patch));
      final session = await EspSession.open(
        device,
        credentials: const ProvCredentials.security2(
          username: 'wifiprov',
          password: 'abcd1234',
        ),
      );
      final endpoint = session.custom('custom-data');
      expect(await endpoint.send(_bytes('ab')), utf8.encode('ba'));
      expect(await endpoint.send(_bytes('xyz')), utf8.encode('zyx'));
    });
  }

  test('Security 2 with a wrong password throws PopMismatch', () async {
    final device = _echoDevice(protoVerJson(secVer: 2, secPatchVer: 1));
    await expectLater(
      EspSession.open(
        device,
        credentials: const ProvCredentials.security2(
          username: 'wifiprov',
          password: 'wrong',
        ),
      ),
      throwsA(isA<PopMismatch>()),
    );
  });

  test('wrong credential kind fails before any handshake message', () async {
    final device = _echoDevice(protoVerJson(secVer: 2, secPatchVer: 1));
    await expectLater(
      EspSession.open(device, credentials: const ProvCredentials.pop('x')),
      throwsA(isA<SchemeMismatch>()),
    );
    expect(device.sessionMessages, 0);
  });

  test('legacy plain-text proto-ver selects Security 1', () async {
    final device = _echoDevice('v1.1', pop: 'abcd1234');
    final session = await EspSession.open(
      device,
      credentials: const ProvCredentials.pop('abcd1234'),
    );
    expect(session.securityVersion, 1);
    expect(session.info.version, 'v1.1');
  });

  test('concurrent requests are serialised in call order', () async {
    final device = _echoDevice(protoVerJson(secVer: 1), pop: 'p');
    final session = await EspSession.open(
      device,
      credentials: const ProvCredentials.pop('p'),
    );
    final endpoint = session.custom('custom-data');
    final results = await Future.wait([
      for (var i = 0; i < 5; i++) endpoint.send(_bytes('message $i')),
    ]);
    for (var i = 0; i < 5; i++) {
      expect(
        utf8.decode(results[i]),
        [...'message $i'.split('').reversed].join(),
      );
    }
    expect(
      [for (final (_, body) in device.plainRequests) utf8.decode(body)],
      [for (var i = 0; i < 5; i++) 'message $i'],
    );
  });

  test('after a failed request the session refuses further requests', () async {
    var calls = 0;
    final device = FakeDevice(
      protoVer: protoVerJson(secVer: 1),
      pop: 'p',
      extraEndpoints: {'custom-data'},
      handlers: {
        'custom-data': (request) {
          calls++;
          if (calls == 1) throw const TransportException('GATT timeout');
          return request;
        },
      },
    );
    final session = await EspSession.open(
      device,
      credentials: const ProvCredentials.pop('p'),
    );
    final endpoint = session.custom('custom-data');
    await expectLater(
      endpoint.send(_bytes('a')),
      throwsA(isA<TransportException>()),
    );
    await expectLater(
      endpoint.send(_bytes('b')),
      throwsA(
        isA<TransportException>().having(
          (e) => e.message,
          'message',
          contains('Reconnect'),
        ),
      ),
    );
    expect(calls, 1);
  });

  test('a disconnect keeps its type on later requests', () async {
    var calls = 0;
    final device = FakeDevice(
      protoVer: protoVerJson(secVer: 1),
      pop: 'p',
      extraEndpoints: {'custom-data'},
      handlers: {
        'custom-data': (request) {
          calls++;
          throw const DeviceDisconnected();
        },
      },
    );
    final session = await EspSession.open(
      device,
      credentials: const ProvCredentials.pop('p'),
    );
    final endpoint = session.custom('custom-data');
    await expectLater(
      endpoint.send(_bytes('a')),
      throwsA(isA<DeviceDisconnected>()),
    );
    await expectLater(
      endpoint.send(_bytes('b')),
      throwsA(isA<DeviceDisconnected>()),
    );
    expect(calls, 1);
  });

  test('unknown endpoint throws UnknownEndpoint without sending', () async {
    final device = _echoDevice(protoVerJson(secVer: 0, caps: ['no_sec']));
    final session = await EspSession.open(device);
    expect(session.custom('nope').isAvailable, isFalse);
    await expectLater(
      session.custom('nope').send(_bytes('x')),
      throwsA(isA<UnknownEndpoint>()),
    );
    expect(device.plainRequests, isEmpty);
  });

  test('close is idempotent and safe after the device dropped', () async {
    final device = _echoDevice(protoVerJson(secVer: 0, caps: ['no_sec']));
    final session = await EspSession.open(device);
    device.dropLink();
    await session.close();
    await session.close();
    expect(device.disconnectCalls, 1);
    await expectLater(
      session.custom('custom-data').send(_bytes('x')),
      throwsA(isA<DeviceDisconnected>()),
    );
  });
}
