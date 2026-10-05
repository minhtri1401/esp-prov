import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:esp_prov_core/src/crypto/aes_gcm_counter.dart';
import 'package:esp_prov_core/src/crypto/bytes.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

void main() {
  final key = List<int>.generate(32, (i) => i);

  test('patch 1 increments the shared counter after each operation', () async {
    final gcm = AesGcmCounter(
      key: key,
      nonce: fromHex('a1b2c3d4e5f6071800000001'),
      incrementNonce: true,
    );
    await gcm.encrypt([1, 2, 3]);
    expect(toHex(gcm.currentNonce), 'a1b2c3d4e5f6071800000002');
    final peer = AesGcmCounter(
      key: key,
      nonce: fromHex('a1b2c3d4e5f6071800000002'),
      incrementNonce: true,
    );
    await gcm.decrypt(await peer.encrypt([4]));
    expect(toHex(gcm.currentNonce), 'a1b2c3d4e5f6071800000003');
  });

  test('counter carries into higher counter bytes', () async {
    final gcm = AesGcmCounter(
      key: key,
      nonce: fromHex('a1b2c3d4e5f60718000000ff'),
      incrementNonce: true,
    );
    await gcm.encrypt([1]);
    expect(toHex(gcm.currentNonce), 'a1b2c3d4e5f6071800000100');
  });

  test('patch 0 keeps the nonce fixed', () async {
    final gcm = AesGcmCounter(
      key: key,
      nonce: fromHex('a1b2c3d4e5f6071800000001'),
      incrementNonce: false,
    );
    await gcm.encrypt([1]);
    await gcm.encrypt([2]);
    expect(toHex(gcm.currentNonce), 'a1b2c3d4e5f6071800000001');
  });

  test('counter overflow throws instead of reusing a nonce', () async {
    final gcm = AesGcmCounter(
      key: key,
      nonce: fromHex('a1b2c3d4e5f60718ffffffff'),
      incrementNonce: true,
    );
    await gcm.encrypt([1]);
    expect(() => gcm.encrypt([2]), throwsA(isA<CryptoException>()));
  });

  test('a modified tag throws CryptoException', () async {
    final nonce = fromHex('a1b2c3d4e5f6071800000001');
    final sealed = await AesGcmCounter(
      key: key,
      nonce: nonce,
      incrementNonce: true,
    ).encrypt([1, 2, 3]);
    sealed[sealed.length - 1] ^= 1;
    final gcm = AesGcmCounter(key: key, nonce: nonce, incrementNonce: true);
    expect(() => gcm.decrypt(sealed), throwsA(isA<CryptoException>()));
  });

  test('input shorter than the tag throws CryptoException', () {
    final gcm = AesGcmCounter(
      key: key,
      nonce: fromHex('a1b2c3d4e5f6071800000001'),
      incrementNonce: true,
    );
    expect(() => gcm.decrypt([1, 2, 3]), throwsA(isA<CryptoException>()));
  });

  for (final patch in [0, 1]) {
    test('matches esp_prov AES-GCM samples for sec_patch_ver $patch', () async {
      final f = loadFixture('sec2_example.json');
      final gcm = AesGcmCounter(
        key: hexField(f, 'session_key').sublist(0, 32),
        nonce: hexField(f, 'device_nonce'),
        incrementNonce: patch == 1,
      );
      for (final m in messages(f, 'messages_patch$patch')) {
        expect(toHex(gcm.currentNonce), m['nonce']);
        if (m['direction'] == 'client_to_device') {
          expect(
            await gcm.encrypt(hexField(m, 'plain')),
            hexField(m, 'cipher'),
          );
        } else {
          expect(
            await gcm.decrypt(hexField(m, 'cipher')),
            hexField(m, 'plain'),
          );
        }
      }
    });
  }
}
