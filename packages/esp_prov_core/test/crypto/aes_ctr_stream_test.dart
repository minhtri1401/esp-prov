import 'dart:typed_data';

import 'package:esp_prov_core/src/crypto/aes_ctr_stream.dart';
import 'package:esp_prov_core/src/crypto/bytes.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

void main() {
  group('counterBlock', () {
    test('adds the block index big-endian', () {
      final iv = fromHex('000102030405060708090a0b0c0d0e0f');
      expect(
        toHex(AesCtrStream.counterBlock(iv, 0x0101)),
        '000102030405060708090a0b0c0d0f10',
      );
    });

    test('carries across all 16 bytes', () {
      final iv = fromHex('0123456789abcdefffffffffffffffff');
      expect(
        toHex(AesCtrStream.counterBlock(iv, 1)),
        '0123456789abcdf00000000000000000',
      );
    });

    test('wraps modulo 2^128', () {
      final iv = Uint8List(16)..fillRange(0, 16, 0xff);
      expect(toHex(AesCtrStream.counterBlock(iv, 2)), '${'0' * 31}1');
    });
  });

  group('apply', () {
    final key = List<int>.generate(32, (i) => i);
    final iv = List<int>.generate(16, (i) => 0xf0 + i);
    final data = List<int>.generate(70, (i) => (i * 7) & 0xff);

    test('a 3-block apply spanning the 64-bit counter wrap', () async {
      final wrapIv = Uint8List.fromList([
        ...List<int>.generate(8, (i) => i + 1),
        ...List<int>.filled(8, 0xff),
      ]);
      final input = List<int>.generate(48, (i) => i * 5 & 0xff);
      final whole = await AesCtrStream(key: key, iv: wrapIv).apply(input);
      final blocks = <int>[];
      for (var i = 0; i < 3; i++) {
        blocks.addAll(
          await AesCtrStream(
            key: key,
            iv: AesCtrStream.counterBlock(wrapIv, i),
          ).apply(input.sublist(i * 16, i * 16 + 16)),
        );
      }
      expect(whole, blocks);
    });

    test('chunked calls equal one call (keystream offset is kept)', () async {
      final whole = await AesCtrStream(key: key, iv: iv).apply(data);
      final chunked = AesCtrStream(key: key, iv: iv);
      final parts = <int>[];
      for (final size in [1, 15, 16, 3, 35]) {
        final start = parts.length;
        parts.addAll(await chunked.apply(data.sublist(start, start + size)));
      }
      expect(parts, whole);
      expect(chunked.offset, 70);
    });

    test('is its own inverse on a fresh stream', () async {
      final cipher = await AesCtrStream(key: key, iv: iv).apply(data);
      final plain = await AesCtrStream(key: key, iv: iv).apply(cipher);
      expect(plain, data);
    });

    test('overlapping calls reserve distinct keystream ranges', () async {
      final whole = await AesCtrStream(key: key, iv: iv).apply(data);
      final stream = AesCtrStream(key: key, iv: iv);
      final results = await Future.wait([
        stream.apply(data.sublist(0, 20)),
        stream.apply(data.sublist(20)),
      ]);
      expect([...results[0], ...results[1]], whole);
    });

    test('empty input consumes nothing', () async {
      final stream = AesCtrStream(key: key, iv: iv);
      expect(await stream.apply(const []), isEmpty);
      expect(stream.offset, 0);
    });

    test('rejects wrong key and IV sizes', () {
      expect(() => AesCtrStream(key: [1], iv: iv), throwsArgumentError);
      expect(() => AesCtrStream(key: key, iv: [1]), throwsArgumentError);
    });
  });

  for (final name in ['sec1_pop.json', 'sec1_no_pop_carry.json']) {
    test('matches the esp_prov keystream in $name', () async {
      final f = loadFixture(name);
      final stream = AesCtrStream(
        key: hexField(f, 'session_key'),
        iv: hexField(f, 'device_random'),
      );
      expect(
        await stream.apply(hexField(f, 'device_public_key')),
        hexField(f, 'client_verify_data'),
      );
      expect(
        await stream.apply(hexField(f, 'client_public_key')),
        hexField(f, 'device_verify_data'),
      );
      for (final m in messages(f)) {
        expect(
          await stream.apply(hexField(m, 'plain')),
          hexField(m, 'cipher'),
          reason: 'message ${m['direction']} ${m['plain']}',
        );
      }
    });
  }
}
