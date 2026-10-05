import 'dart:typed_data';

import 'package:cryptography_plus/cryptography_plus.dart';
import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:esp_prov_core/src/proto/constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/session.pb.dart' as pb;
import 'package:test/test.dart';

import '../support/fixtures.dart';
import '../support/replay_transport.dart';

Security1 _fixedClient(Map<String, Object?> f) => Security1.withKeyPair(
  pop: f['pop']! as String,
  keyPair: () => X25519().newKeyPairFromSeed(hexField(f, 'client_private_key')),
);

List<Exchange> _handshake(Map<String, Object?> f, {List<int>? resp1}) => [
  Exchange(
    'prov-session',
    hexField(f, 'session_cmd0'),
    hexField(f, 'session_resp0'),
  ),
  Exchange(
    'prov-session',
    hexField(f, 'session_cmd1'),
    resp1 ?? hexField(f, 'session_resp1'),
  ),
];

void main() {
  for (final name in ['sec1_pop.json', 'sec1_no_pop_carry.json']) {
    test('handshake and messages match esp_prov ($name)', () async {
      final f = loadFixture(name);
      final transport = ReplayTransport(_handshake(f));
      final scheme = _fixedClient(f);
      await scheme.handshake(transport);
      expect(transport.exchanges, isEmpty);

      for (final m in messages(f)) {
        if (m['direction'] == 'client_to_device') {
          expect(
            await scheme.encrypt(hexField(m, 'plain')),
            hexField(m, 'cipher'),
          );
        } else {
          expect(
            await scheme.decrypt(hexField(m, 'cipher')),
            hexField(m, 'plain'),
          );
        }
      }
    });
  }

  test('wrong device verify data throws PopMismatch', () async {
    final f = loadFixture('sec1_pop.json');
    final resp1 = pb.SessionData.fromBuffer(hexField(f, 'session_resp1'));
    final tampered = Uint8List.fromList(resp1.sec1.sr1.deviceVerifyData);
    tampered[0] ^= 0x01;
    resp1.sec1.sr1.deviceVerifyData = tampered;
    final transport = ReplayTransport(
      _handshake(f, resp1: resp1.writeToBuffer()),
    );
    await expectLater(
      _fixedClient(f).handshake(transport),
      throwsA(isA<PopMismatch>()),
    );
  });

  test('device dropping the link after Cmd1 is a PopMismatch', () async {
    final f = loadFixture('sec1_pop.json');
    final transport = ReplayTransport([
      _handshake(f).first,
      Exchange(
        'prov-session',
        hexField(f, 'session_cmd1'),
        const [],
        error: const DeviceDisconnected(),
      ),
    ]);
    await expectLater(
      _fixedClient(f).handshake(transport),
      throwsA(isA<PopMismatch>()),
    );
  });

  test('a disconnect during Cmd0 stays DeviceDisconnected', () async {
    final f = loadFixture('sec1_pop.json');
    final transport = ReplayTransport([
      Exchange(
        'prov-session',
        hexField(f, 'session_cmd0'),
        const [],
        error: const DeviceDisconnected(),
      ),
    ]);
    await expectLater(
      _fixedClient(f).handshake(transport),
      throwsA(isA<DeviceDisconnected>()),
    );
  });

  test('error status in SessionResp0 throws HandshakeFailed', () async {
    final f = loadFixture('sec1_pop.json');
    final resp0 = pb.SessionData.fromBuffer(hexField(f, 'session_resp0'));
    resp0.sec1.sr0.status = pb.Status.InvalidArgument;
    final transport = ReplayTransport([
      Exchange(
        'prov-session',
        hexField(f, 'session_cmd0'),
        resp0.writeToBuffer(),
      ),
    ]);
    await expectLater(
      _fixedClient(f).handshake(transport),
      throwsA(
        isA<HandshakeFailed>()
            .having((e) => e.status, 'status', ProvStatus.invalidArgument)
            .having((e) => e is PopMismatch, 'is PopMismatch', isFalse),
      ),
    );
  });

  test('encrypt before handshake is a StateError', () {
    expect(() => Security1(pop: 'x').encrypt(Uint8List(1)), throwsStateError);
  });
}
