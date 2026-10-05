import 'dart:typed_data';

import 'package:cryptography_plus/cryptography_plus.dart';
import 'package:esp_prov_core/src/errors/prov_exception.dart';

/// AES-256-GCM with the protocomm Security 2 nonce rules.
///
/// The 12-byte nonce starts as the device's `device_nonce` (8-byte session id
/// followed by a 4-byte big-endian counter). With [incrementNonce] (firmware
/// `sec_patch_ver >= 1`) the counter is incremented after every encrypt and
/// every decrypt, one counter shared by both directions. Without it (legacy
/// `sec_patch_ver == 0` firmware) the nonce never changes. The 16-byte tag is
/// appended to the ciphertext and there is no associated data.
final class AesGcmCounter {
  /// Creates a cipher from the first 32 bytes of the SRP session key [key],
  /// the device [nonce] and the patch-level nonce rule.
  new({
    required List<int> key,
    required List<int> nonce,
    required this.incrementNonce,
  }) : _key = SecretKeyData(List<int>.of(key)),
       _nonce = Uint8List.fromList(nonce) {
    if (key.length != 32) {
      throw ArgumentError.value(key.length, 'key', 'must be 32 bytes');
    }
    if (nonce.length != 12) {
      throw ArgumentError.value(nonce.length, 'nonce', 'must be 12 bytes');
    }
  }

  /// Length of the authentication tag appended to every ciphertext.
  static const tagLength = 16;

  /// Whether the counter advances after each operation.
  final bool incrementNonce;

  final AesGcm _gcm = AesGcm.with256bits();
  final SecretKeyData _key;
  final Uint8List _nonce;
  bool _exhausted = false;

  /// The nonce the next encrypt or decrypt will use.
  Uint8List get currentNonce => Uint8List.fromList(_nonce);

  /// Encrypts [plain] and returns `ciphertext | tag`.
  Future<Uint8List> encrypt(List<int> plain) async {
    final nonce = _takeNonce();
    final box = await _gcm.encrypt(plain, secretKey: _key, nonce: nonce);
    return box.concatenation(nonce: false);
  }

  /// Decrypts `ciphertext | tag`. Throws [CryptoException] if the tag does
  /// not verify or the input is shorter than the tag.
  Future<Uint8List> decrypt(List<int> cipherWithTag) async {
    final nonce = _takeNonce();
    if (cipherWithTag.length < tagLength) {
      throw CryptoException(
        'Ciphertext of ${cipherWithTag.length} bytes is shorter than the '
        '$tagLength-byte GCM tag.',
      );
    }
    final box = SecretBox.fromConcatenation(
      cipherWithTag,
      nonceLength: 0,
      macLength: tagLength,
    );
    try {
      final plain = await _gcm.decrypt(
        SecretBox(box.cipherText, nonce: nonce, mac: box.mac),
        secretKey: _key,
      );
      return Uint8List.fromList(plain);
    } on SecretBoxAuthenticationError {
      throw const CryptoException(
        'AES-GCM tag mismatch: the response was not produced with this '
        'session key and nonce.',
      );
    }
  }

  Uint8List _takeNonce() {
    if (_exhausted) {
      throw const CryptoException('AES-GCM nonce counter overflow.');
    }
    final used = Uint8List.fromList(_nonce);
    if (incrementNonce) {
      final view = ByteData.sublistView(_nonce);
      final counter = view.getUint32(8);
      if (counter == 0xffffffff) {
        _exhausted = true;
      } else {
        view.setUint32(8, counter + 1);
      }
    }
    return used;
  }
}
