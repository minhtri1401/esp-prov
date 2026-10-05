import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cryptography_plus/cryptography_plus.dart';

/// One continuous AES-256-CTR keystream, as used by protocomm Security 1.
///
/// The device and esp_prov use a single CTR context for the whole session:
/// every encrypt and every decrypt consumes the next bytes of the same
/// keystream. [apply] therefore keeps a byte [offset] across calls.
///
/// cryptography_plus only offers one-shot encryption, so each call derives
/// the counter block for `offset ~/ 16` itself (16-byte IV plus block index,
/// big-endian, full 128-bit carry like mbedTLS), encrypts zero bytes from that
/// counter to get the keystream, and XORs it with the data, skipping the
/// `offset % 16` bytes already used in the first block. Runs are split where
/// the low 64 bits of the counter wrap, so backends that only increment a
/// 64-bit counter (WebCrypto) still produce the mbedTLS keystream.
final class AesCtrStream {
  /// Creates a stream for a 32-byte [key] and 16-byte [iv].
  new({required List<int> key, required List<int> iv})
    : _key = SecretKeyData(List<int>.of(key)),
      _iv = Uint8List.fromList(iv) {
    if (key.length != 32) {
      throw ArgumentError.value(key.length, 'key', 'must be 32 bytes');
    }
    if (iv.length != 16) {
      throw ArgumentError.value(iv.length, 'iv', 'must be 16 bytes');
    }
  }

  static const _blockSize = 16;
  static final BigInt _two64 = BigInt.one << 64;

  final AesCtr _aes = AesCtr.with256bits(macAlgorithm: MacAlgorithm.empty);
  final SecretKeyData _key;
  final Uint8List _iv;
  int _offset = 0;

  /// Number of keystream bytes consumed so far.
  int get offset => _offset;

  /// XORs [data] with the next `data.length` keystream bytes.
  ///
  /// Encryption and decryption are the same operation. The keystream range is
  /// reserved synchronously, so overlapping calls never reuse bytes.
  Future<Uint8List> apply(List<int> data) async {
    if (data.isEmpty) return Uint8List(0);
    final start = _offset;
    _offset += data.length;

    final skip = start % _blockSize;
    final totalBlocks = (skip + data.length + _blockSize - 1) ~/ _blockSize;
    final keystream = Uint8List(totalBlocks * _blockSize);

    var done = 0;
    var block = start ~/ _blockSize;
    while (done < totalBlocks) {
      final counter = counterBlock(_iv, block);
      final run = math.min(totalBlocks - done, _blocksBeforeLow64Wrap(counter));
      final box = await _aes.encrypt(
        Uint8List(run * _blockSize),
        secretKey: _key,
        nonce: counter,
      );
      keystream.setRange(
        done * _blockSize,
        (done + run) * _blockSize,
        box.cipherText,
      );
      done += run;
      block += run;
    }

    final out = Uint8List(data.length);
    for (var i = 0; i < data.length; i++) {
      out[i] = data[i] ^ keystream[skip + i];
    }
    return out;
  }

  /// The counter block for [blockIndex]: [iv] + [blockIndex] as a 128-bit
  /// big-endian integer, wrapping modulo 2^128.
  static Uint8List counterBlock(List<int> iv, int blockIndex) {
    if (blockIndex < 0) {
      throw ArgumentError.value(blockIndex, 'blockIndex', 'must be >= 0');
    }
    final out = Uint8List.fromList(iv);
    var carry = blockIndex;
    for (var i = out.length - 1; i >= 0 && carry != 0; i--) {
      final sum = out[i] + (carry & 0xff);
      out[i] = sum & 0xff;
      carry = (carry >> 8) + (sum >> 8);
    }
    return out;
  }

  static int _blocksBeforeLow64Wrap(Uint8List counter) {
    var low = BigInt.zero;
    for (var i = 8; i < 16; i++) {
      low = (low << 8) | BigInt.from(counter[i]);
    }
    final remaining = _two64 - low;
    return remaining > BigInt.from(1 << 30) ? 1 << 30 : remaining.toInt();
  }
}
