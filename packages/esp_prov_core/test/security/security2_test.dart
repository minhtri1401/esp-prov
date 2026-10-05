import 'dart:typed_data';

import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:esp_prov_core/src/proto/session.pb.dart' as pb;
import 'package:test/test.dart';

import '../support/fixtures.dart';
import '../support/replay_transport.dart';

Security2 _fixedClient(
  Map<String, Object?> f, {
  required int patchVersion,
  List<BigInt>? keys,
}) {
  final queue = keys ?? [BigInt.parse(f['a']! as String, radix: 16)];
  return Security2.withPrivateKeys(
    username: f['username']! as String,
    password: f['password']! as String,
    patchVersion: patchVersion,
    nextPrivateKey: () => queue.removeAt(0),
  );
}

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
  for (final patch in [0, 1]) {
    test('handshake and AES-GCM match esp_prov (patch $patch)', () async {
      final f = loadFixture('sec2_example.json');
      final scheme = _fixedClient(f, patchVersion: patch);
      await scheme.handshake(ReplayTransport(_handshake(f)));
      for (final m in messages(f, 'messages_patch$patch')) {
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

  for (final name in ['sec2_short_b.json', 'sec2_short_s.json']) {
    test('handshake succeeds for $name', () async {
      final f = loadFixture(name);
      final transport = ReplayTransport(_handshake(f));
      await _fixedClient(f, patchVersion: 1).handshake(transport);
      expect(transport.exchanges, isEmpty);
    });
  }

  test('re-rolls a until A is 384 bytes', () async {
    final f = loadFixture('sec2_example.json');
    // a = 0 gives A = 1 (one byte), so the client must draw again.
    final scheme = _fixedClient(
      f,
      patchVersion: 1,
      keys: [BigInt.zero, BigInt.parse(f['a']! as String, radix: 16)],
    );
    final transport = ReplayTransport(_handshake(f));
    await scheme.handshake(transport);
    expect(transport.exchanges, isEmpty);
  });

  test('wrong device proof throws PopMismatch', () async {
    final f = loadFixture('sec2_example.json');
    final resp1 = pb.SessionData.fromBuffer(hexField(f, 'session_resp1'));
    final proof = Uint8List.fromList(resp1.sec2.sr1.deviceProof);
    proof[10] ^= 0xff;
    resp1.sec2.sr1.deviceProof = proof;
    await expectLater(
      _fixedClient(
        f,
        patchVersion: 1,
      ).handshake(ReplayTransport(_handshake(f, resp1: resp1.writeToBuffer()))),
      throwsA(isA<PopMismatch>()),
    );
  });

  test(
    'device closing the link after the client proof is PopMismatch',
    () async {
      final f = loadFixture('sec2_example.json');
      final transport = ReplayTransport([
        _handshake(f).first,
        Exchange(
          'prov-session',
          hexField(f, 'session_cmd1'),
          const [],
          error: const TransportException('GATT error 133'),
        ),
      ]);
      await expectLater(
        _fixedClient(f, patchVersion: 1).handshake(transport),
        throwsA(isA<PopMismatch>()),
      );
    },
  );

  test('a short device nonce throws HandshakeFailed', () async {
    final f = loadFixture('sec2_example.json');
    final resp1 = pb.SessionData.fromBuffer(hexField(f, 'session_resp1'));
    resp1.sec2.sr1.deviceNonce = Uint8List(8);
    await expectLater(
      _fixedClient(
        f,
        patchVersion: 1,
      ).handshake(ReplayTransport(_handshake(f, resp1: resp1.writeToBuffer()))),
      throwsA(
        isA<HandshakeFailed>().having(
          (e) => e is PopMismatch,
          'is PopMismatch',
          isFalse,
        ),
      ),
    );
  });
}
