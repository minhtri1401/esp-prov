import 'dart:typed_data';

import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:esp_prov_core/src/crypto/bytes.dart';
import 'package:esp_prov_core/src/crypto/srp6a.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

void main() {
  test('group constants are RFC 5054 3072-bit with g = 5', () {
    expect(Srp6aClient.n.bitLength, 3072);
    expect(Srp6aClient.g, BigInt.from(5));
    expect(bigIntToBytes(Srp6aClient.n).length, Srp6aClient.nLength);
  });

  test('random private key is 256 bits with the top bit set', () {
    final a = Srp6aClient.randomPrivateKey();
    expect(a.bitLength, 256);
  });

  test('publicKey returns null when A has a leading zero byte', () {
    // a = 0 gives A = 1, which serialises to a single byte.
    expect(Srp6aClient.publicKey(BigInt.zero), isNull);
  });

  test('x uses the salt bytes as sent, including a leading zero', () {
    // esp_srp.c hashes the raw salt buffer; Python esp_prov would strip the
    // leading zero. The two salts must therefore give different proofs.
    final f = loadFixture('sec2_example.json');
    final a = BigInt.parse(f['a']! as String, radix: 16);
    final rest = hexField(f, 'salt');
    Uint8List proofFor(Uint8List salt) => Srp6aClient.computeProof(
      username: f['username']! as String,
      password: f['password']! as String,
      a: a,
      clientPublicKey: hexField(f, 'client_public_key'),
      salt: salt,
      serverPublicKey: hexField(f, 'device_public_key'),
    ).clientProof;
    expect(proofFor(Uint8List.fromList([0, ...rest])), isNot(proofFor(rest)));
  });

  for (final name in [
    'sec2_example.json',
    'sec2_short_b.json',
    'sec2_short_s.json',
  ]) {
    test('A, M1, M2 and K match esp_prov for $name', () {
      final f = loadFixture(name);
      final a = BigInt.parse(f['a']! as String, radix: 16);
      final clientPublic = Srp6aClient.publicKey(a);
      expect(clientPublic, hexField(f, 'client_public_key'));
      expect(clientPublic!.length, 384);

      final proof = Srp6aClient.computeProof(
        username: f['username']! as String,
        password: f['password']! as String,
        a: a,
        clientPublicKey: clientPublic,
        salt: hexField(f, 'salt'),
        serverPublicKey: hexField(f, 'device_public_key'),
      );
      expect(proof.clientProof, hexField(f, 'client_proof'));
      expect(proof.expectedServerProof, hexField(f, 'device_proof'));
      expect(proof.sessionKey, hexField(f, 'session_key'));
    });
  }

  test('B = 0 (mod N) is rejected', () {
    final f = loadFixture('sec2_example.json');
    expect(
      () => Srp6aClient.computeProof(
        username: 'wifiprov',
        password: 'abcd1234',
        a: BigInt.parse(f['a']! as String, radix: 16),
        clientPublicKey: hexField(f, 'client_public_key'),
        salt: hexField(f, 'salt'),
        serverPublicKey: bigIntToBytes(Srp6aClient.n),
      ),
      throwsA(isA<HandshakeFailed>()),
    );
    expect(
      () => Srp6aClient.computeProof(
        username: 'wifiprov',
        password: 'abcd1234',
        a: BigInt.one,
        clientPublicKey: Uint8List(384),
        salt: hexField(f, 'salt'),
        serverPublicKey: Uint8List(1),
      ),
      throwsA(isA<HandshakeFailed>()),
    );
  });
}
